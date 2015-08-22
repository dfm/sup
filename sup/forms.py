# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["SignupForm", "LoginForm"]

from flask_wtf import Form
from wtforms.validators import DataRequired, Email
from wtforms import StringField, PasswordField, BooleanField


class SignupForm(Form):

    username = StringField("username", validators=[
        DataRequired(message="A username is required."),
    ])
    email = StringField("email", validators=[
        Email(message="Invalid email address."),
    ])
    password = PasswordField("password", validators=[
        DataRequired(message="A password is required."),
    ])


class LoginForm(Form):

    username = StringField("username", validators=[
        DataRequired(message="A username is required."),
    ])
    password = PasswordField("password", validators=[
        DataRequired(message="A password is required."),
    ])
    remember = BooleanField("remember")
