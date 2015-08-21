# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["api"]

import flask
# from flask.ext.login import current_user, login_required

from . import factory
# from .models import db

api = flask.Blueprint("api", __name__)


def create_app(settings_override=None):
    app = factory.create_app([api], __name__, settings_override)

    # # Register custom error handlers
    # app.errorhandler(OverholtError)(on_overholt_error)
    # app.errorhandler(OverholtFormError)(on_overholt_form_error)
    # app.errorhandler(404)(on_404)

    return app


@api.route("/")
def index():
    return "blah"
