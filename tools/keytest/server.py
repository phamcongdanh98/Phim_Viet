import http.server, sys, os
LOG = sys.argv[2]
class H(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0)); body = self.rfile.read(n).decode()
        with open(LOG, 'a') as f: f.write(body + "\n")
        self.send_response(204); self.end_headers()
    def log_message(self, *a): pass
os.chdir(os.path.dirname(os.path.abspath(__file__)))
http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), H).serve_forever()
