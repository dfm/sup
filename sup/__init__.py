# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["create_app"]

from flask import Flask
from .core import db, login_manager


def create_app(settings_override=None):
    app = Flask(__name__, instance_relative_config=True)

    app.config.from_object("sup.settings")
    app.config.from_pyfile("settings.cfg", silent=True)
    app.config.from_object(settings_override)

    db.init_app(app)
    login_manager.init_app(app)

    from .api import api
    app.register_blueprint(api, url_prefix="/api")

    from .frontend import frontend
    app.register_blueprint(frontend)

    return app
