import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader("inline_daemon", str(ROOT / "src/daemon/omarchy-inline"))
spec = importlib.util.spec_from_loader(loader.name, loader)
inline_daemon = importlib.util.module_from_spec(spec)
loader.exec_module(inline_daemon)


class OllamaHandler(BaseHTTPRequestHandler):
    request_body = None

    def do_POST(self):
        length = int(self.headers["Content-Length"])
        type(self).request_body = json.loads(self.rfile.read(length))
        payload = json.dumps({"response": " continuation words\nignored"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        pass


class PredictorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.original_config_home = os.environ.get("XDG_CONFIG_HOME")
        os.environ["XDG_CONFIG_HOME"] = self.temp.name
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), OllamaHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        if self.original_config_home is None:
            os.environ.pop("XDG_CONFIG_HOME", None)
        else:
            os.environ["XDG_CONFIG_HOME"] = self.original_config_home
        self.temp.cleanup()

    def test_predicts_with_bounded_context_and_cleans_multiline_output(self):
        config = dict(inline_daemon.DEFAULT_CONFIG)
        config.update({
            "ollama_url": f"http://127.0.0.1:{self.server.server_port}",
            "context_chars": 5,
        })
        predictor = inline_daemon.Predictor(config)

        self.assertEqual(predictor.suggest("0123456789"), " continuation words")
        prompt = OllamaHandler.request_body["prompt"]
        self.assertTrue(prompt.endswith("56789"))
        self.assertEqual(OllamaHandler.request_body["stream"], False)

    def test_disabled_never_calls_model(self):
        marker = inline_daemon.config_home() / "disabled"
        marker.parent.mkdir(parents=True)
        marker.touch()
        OllamaHandler.request_body = None

        self.assertEqual(inline_daemon.Predictor(inline_daemon.DEFAULT_CONFIG).suggest("hello"), "")
        self.assertIsNone(OllamaHandler.request_body)


class CleanCompletionTest(unittest.TestCase):
    def test_removes_labels_quotes_and_extra_paragraphs(self):
        self.assertEqual(inline_daemon.clean_completion('Continuation: "hello there"\nmore'), "hello there")
        self.assertEqual(inline_daemon.clean_completion('"hello there"'), "hello there")


if __name__ == "__main__":
    unittest.main()
