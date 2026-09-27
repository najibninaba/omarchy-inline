#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#include <fcitx-utils/capabilityflags.h>
#include <fcitx-utils/key.h>
#include <fcitx-utils/utf8.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>
#include <fcitx/event.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputcontextmanager.h>
#include <fcitx/inputcontextproperty.h>
#include <fcitx/inputpanel.h>
#include <fcitx/instance.h>
#include <fcitx/text.h>

namespace fcitx {

struct CotypistState final : InputContextProperty {
    uint64_t generation = 0;
    std::string suggestion;
};

struct Request {
    TrackableObjectReference<InputContext> context;
    uint64_t generation;
    std::string text;
};

class Cotypist final : public AddonInstance {
public:
    explicit Cotypist(Instance *instance) : instance_(instance) {
        instance_->inputContextManager().registerProperty("cotypistState", &stateFactory_);
        handlers_.emplace_back(instance_->watchEvent<EventType::InputContextSurroundingTextUpdated>(
            EventWatcherPhase::Default, [this](SurroundingTextUpdatedEvent &event) {
                request(event.inputContext());
            }));
        handlers_.emplace_back(instance_->watchEvent<EventType::InputContextCapabilityChanged>(
            EventWatcherPhase::Default, [this](CapabilityChangedEvent &event) {
                request(event.inputContext());
            }));
        handlers_.emplace_back(instance_->watchEvent<EventType::InputContextFocusIn>(
            EventWatcherPhase::Default, [this](FocusInEvent &event) {
                request(event.inputContext());
            }));
        handlers_.emplace_back(instance_->watchEvent<EventType::InputContextFocusOut>(
            EventWatcherPhase::Default, [this](FocusOutEvent &event) {
                clear(event.inputContext());
            }));
        handlers_.emplace_back(instance_->watchEvent<EventType::InputContextReset>(
            EventWatcherPhase::Default, [this](InputContextEvent &event) {
                clear(event.inputContext());
            }));
        handlers_.emplace_back(instance_->watchEvent<EventType::InputContextKeyEvent>(
            EventWatcherPhase::PreInputMethod, [this](KeyEvent &event) {
                accept(event);
            }));
        worker_ = std::thread([this] { work(); });
    }

    ~Cotypist() override {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stopping_ = true;
        }
        condition_.notify_one();
        if (worker_.joinable()) worker_.join();
    }

private:
    bool eligible(InputContext *context) const {
        auto flags = context->capabilityFlags();
        return context->hasFocus() &&
               flags.test(CapabilityFlag::SurroundingText) &&
               flags.test(CapabilityFlag::Preedit) &&
               !flags.test(CapabilityFlag::Password) &&
               !flags.test(CapabilityFlag::Sensitive) &&
               !flags.test(CapabilityFlag::Terminal) &&
               !flags.test(CapabilityFlag::Disable) &&
               context->surroundingText().isValid() &&
               context->surroundingText().cursor() == context->surroundingText().anchor();
    }

    void request(InputContext *context) {
        auto *state = context->propertyFor(&stateFactory_);
        const auto generation = ++state->generation;
        state->suggestion.clear();
        updatePreedit(context);
        if (!eligible(context)) return;

        const auto &surrounding = context->surroundingText();
        const auto &text = surrounding.text();
        if (!utf8::validate(text)) return;
        const auto bytes = utf8::ncharByteLength(text.begin(), surrounding.cursor());
        std::string prefix = text.substr(0, static_cast<size_t>(bytes));
        if (prefix.size() > 4096) prefix.erase(0, prefix.size() - 4096);
        if (std::all_of(prefix.begin(), prefix.end(), [](unsigned char c) { return std::isspace(c); })) return;

        {
            std::lock_guard<std::mutex> lock(mutex_);
            pending_ = Request{context->watch(), generation, std::move(prefix)};
        }
        condition_.notify_one();
    }

    void work() {
        while (true) {
            Request request;
            {
                std::unique_lock<std::mutex> lock(mutex_);
                condition_.wait(lock, [this] { return stopping_ || pending_.has_value(); });
                if (stopping_) return;
                request = std::move(*pending_);
                pending_.reset();
                condition_.wait_for(lock, std::chrono::milliseconds(180),
                                    [this] { return stopping_ || pending_.has_value(); });
                if (stopping_) return;
                if (pending_) continue;
            }
            auto result = query(request.text);
            instance_->eventDispatcher().scheduleWithContext(
                request.context, [this, contextRef = request.context,
                                  generation = request.generation,
                                  result = std::move(result)]() mutable {
                    auto *context = contextRef.get();
                    if (!context || !eligible(context)) return;
                    auto *state = context->propertyFor(&stateFactory_);
                    if (state->generation != generation) return;
                    state->suggestion = std::move(result);
                    updatePreedit(context);
                });
        }
    }

    static std::string query(const std::string &text) {
        const char *runtime = std::getenv("XDG_RUNTIME_DIR");
        if (!runtime) return {};
        std::string path = std::string(runtime) + "/cotypist-omarchy/daemon.sock";
        if (path.size() >= sizeof(sockaddr_un::sun_path)) return {};

        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) return {};
        sockaddr_un address{};
        address.sun_family = AF_UNIX;
        std::strncpy(address.sun_path, path.c_str(), sizeof(address.sun_path) - 1);
        if (connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) != 0) {
            close(fd);
            return {};
        }
        const char command = 'S';
        if (!sendAll(fd, &command, 1) || !sendAll(fd, text.data(), text.size())) {
            close(fd);
            return {};
        }
        shutdown(fd, SHUT_WR);
        std::string result;
        std::array<char, 1024> buffer{};
        ssize_t count;
        while ((count = recv(fd, buffer.data(), buffer.size(), 0)) > 0 && result.size() < 4096) {
            result.append(buffer.data(), static_cast<size_t>(count));
        }
        close(fd);
        return result;
    }

    static bool sendAll(int fd, const char *data, size_t size) {
        while (size > 0) {
            const auto sent = send(fd, data, size, MSG_NOSIGNAL);
            if (sent <= 0) return false;
            data += sent;
            size -= static_cast<size_t>(sent);
        }
        return true;
    }

    void accept(KeyEvent &event) {
        if (event.isRelease() || !event.key().check(Key(FcitxKey_Tab))) return;
        auto *context = event.inputContext();
        if (!eligible(context)) return;
        auto *state = context->propertyFor(&stateFactory_);
        if (state->suggestion.empty()) return;

        size_t end = 0;
        while (end < state->suggestion.size() && std::isspace(static_cast<unsigned char>(state->suggestion[end]))) ++end;
        while (end < state->suggestion.size() && !std::isspace(static_cast<unsigned char>(state->suggestion[end]))) ++end;
        while (end < state->suggestion.size() && std::isspace(static_cast<unsigned char>(state->suggestion[end]))) ++end;
        auto accepted = state->suggestion.substr(0, end);
        ++state->generation;
        state->suggestion.clear();
        updatePreedit(context);
        context->commitString(accepted);
        event.filterAndAccept();
    }

    void clear(InputContext *context) {
        auto *state = context->propertyFor(&stateFactory_);
        ++state->generation;
        state->suggestion.clear();
        updatePreedit(context);
    }

    void updatePreedit(InputContext *context) const {
        auto *state = context->propertyFor(&stateFactory_);
        Text preedit;
        if (!state->suggestion.empty()) {
            preedit.append(state->suggestion,
                           {TextFormatFlag::Underline, TextFormatFlag::DontCommit});
        }
        preedit.setCursor(0);
        context->inputPanel().setClientPreedit(preedit);
        context->updatePreedit();
        context->updateUserInterface(UserInterfaceComponent::InputPanel);
    }

    Instance *instance_;
    FactoryFor<CotypistState> stateFactory_{
        [](InputContext &) { return new CotypistState; }};
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>> handlers_;
    std::mutex mutex_;
    std::condition_variable condition_;
    std::optional<Request> pending_;
    bool stopping_ = false;
    std::thread worker_;
};

class CotypistFactory final : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new Cotypist(manager->instance());
    }
};

} // namespace fcitx

FCITX_ADDON_FACTORY_V2(cotypist, fcitx::CotypistFactory)
