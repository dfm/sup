# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = [
    "CreateTablesCommand", "DropTablesCommand",
    "CreateUserCommand",
]

from sqlalchemy import func
from flask.ext.script import Command, prompt, prompt_pass

from .core import db
from .models import User, Sup


class CreateTablesCommand(Command):
    def run(self):
        db.create_all()


class DropTablesCommand(Command):
    def run(self):
        db.drop_all()


class CreateUserCommand(Command):
    def run(self):
        while True:
            username = prompt("username")
            if not User.query.filter(
                    func.lower(User.username) == func.lower(username)
            ).count():
                break
            print("username taken")

        while True:
            password = prompt_pass("password")
            password_confirm = prompt_pass("confirm password")
            if len(password) and password == password_confirm:
                break
            print("invalid or non-matching passwords")

        user = User(username, password)
        db.session.add(user)
        db.session.commit()


def _get_user(prompt_text="username", password=True):
    while True:
        username = prompt(prompt_text)
        user = User.query.filter(
            func.lower(User.username) == func.lower(username)
        ).first()
        if user is not None:
            break
        print("unknown user")

    while password:
        password = prompt_pass("Password")
        if user.check_password(password):
            break
        print("incorrect password")

    return user


class SendSupCommand(Command):
    def run(self):
        from_user = _get_user("from username", password=True)
        to_user = _get_user("to username", password=False)
        lat = float(prompt("lat"))
        lng = float(prompt("lng"))

        sup = Sup(from_user, to_user, lat, lng)
        db.session.add(sup)
        db.session.commit()
