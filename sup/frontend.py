# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["frontend"]

import sqlalchemy

import flask
from flask_login import current_user, login_required, login_user, logout_user

from .models import User
from .core import db, login_manager
from .forms import SignupForm, LoginForm

frontend = flask.Blueprint("frontend", __name__)


@login_manager.user_loader
def load_user(userid):
    return User.query.filter_by(username=userid).first()


@frontend.route("/")
def index():
    if current_user.is_authenticated():
        return flask.render_template("app.html")
    form = SignupForm()
    return flask.render_template("signup.html", form=form)


@frontend.route("/signup", methods=["GET", "POST"])
def signup():
    if current_user.is_authenticated():
        return flask.redirect(flask.url_for("frontend.index"))

    errors = None
    form = SignupForm()
    if form.validate_on_submit():
        user = User(form.username.data, form.password.data,
                    email=form.email.data)
        db.session.add(user)
        try:
            db.session.commit()
        except sqlalchemy.exc.IntegrityError:
            errors = [
                "A user with that username already exists."
            ]
        else:
            flask.flash("Successfully signed up!")

            return flask.redirect(flask.url_for("frontend.index"))

    return flask.render_template("signup.html", form=form, errors=errors)


@frontend.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated():
        return flask.redirect(flask.url_for("frontend.index"))

    errors = None
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user is None or not user.check_password(form.password.data):
            errors = [
                "Invalid username or password."
            ]
        else:
            login_user(user, remember=form.remember.data)
            flask.flash("Successfully logged in.")

            next_url = flask.request.args.get("next",
                                              flask.url_for("frontend.index"))

            return flask.redirect(next_url)

    return flask.render_template("login.html", form=form, errors=errors)


@frontend.route("/logout")
def logout():
    logout_user()
    flask.flash("Successfully logged out.")
    return flask.redirect(flask.url_for("frontend.index"))


@frontend.route("/forgot")
def forgot():
    return "dude"
