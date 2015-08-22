# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["api"]

import base64

import flask
from flask_login import current_user, login_required

from .models import User, Sup
from .core import db, login_manager

api = flask.Blueprint("api", __name__)


@login_manager.request_loader
def load_user_from_request(request):
    api_key = request.args.get("api_key")
    if api_key:
        user = User.query.filter_by(api_key=api_key).first()
        if user:
            return user

    api_key = request.headers.get("Authorization")
    if api_key:
        api_key = api_key.replace("Basic ", "", 1)
        try:
            api_key = base64.b64decode(api_key)
        except TypeError:
            pass
        user = User.query.filter_by(api_key=api_key).first()
        if user:
            return user

    return None


@api.errorhandler(404)
def error_handler(e):
    resp = flask.jsonify(message="Not Found")
    resp.status_code = 404
    return resp


@api.route("/")
def index():
    if current_user.is_authenticated():
        return flask.jsonify(current_user.to_dict())
    return flask.jsonify(message="s'up")


@api.route("/sups")
@login_required
def list_sups():
    q = Sup.query.filter((Sup.to_user == current_user) & (Sup.seen == False))
    q = q.order_by(Sup.when.desc())
    results = q.all()
    return flask.jsonify(dict(count=len(results), results=[
        s.to_dict() for s in results
    ]))


@api.route("/sup/<username>")
@login_required
def send_sup(username):
    user = User.query.filter_by(username=username).first()
    if user is None:
        return (flask.jsonify(message="Unknown user '{0}'".format(username)),
                404)

    try:
        lat = float(flask.request.args.get("lng", None))
        lng = float(flask.request.args.get("lng", None))
    except ValueError:
        return flask.jsonify(message="Invalid coordinates"), 404

    sup = Sup(current_user, user, lat, lng)
    db.session.add(sup)
    db.session.commit()

    return flask.jsonify(current_user.to_dict())
