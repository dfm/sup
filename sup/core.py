# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["db", "login_manager"]

from flask_login import LoginManager
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
login_manager = LoginManager()
