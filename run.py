#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = "application"

from tornado.ioloop import IOLoop
from tornado.wsgi import WSGIContainer
from tornado.httpserver import HTTPServer

from werkzeug.serving import run_simple

from sup import create_app

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", default=3031, type=int,
                        help="the port to expose")
    parser.add_argument("-d", "--debug", action="store_true",
                        help="debugging interface")
    args = parser.parse_args()

    application = create_app()

    if args.debug:
        run_simple("0.0.0.0", args.port, application, use_reloader=True,
                   use_debugger=True)
    else:
        http_server = HTTPServer(WSGIContainer(application))
        http_server.listen(args.port)
        IOLoop.instance().start()
