# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["create_app"]

from flask import Flask

from .core import db


def create_app(bps, package_name, settings_override=None):
    app = Flask(package_name, instance_relative_config=True)

    app.config.from_object("sup.settings")
    app.config.from_pyfile("settings.cfg", silent=True)
    app.config.from_object(settings_override)

    db.init_app(app)

    for bp in bps:
        app.register_blueprint(bp)

    return app
