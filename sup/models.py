# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["User"]

from datetime import datetime
from werkzeug.security import (
    generate_password_hash, check_password_hash, gen_salt
)

from .core import db
from .errors import SupBlockError


follows = db.Table(
    "follows",
    db.Column("follower_id", db.Integer, db.ForeignKey("users.id")),
    db.Column("followee_id", db.Integer, db.ForeignKey("users.id")),
    db.UniqueConstraint("follower_id", "followee_id")
)

blocks = db.Table(
    "blocks",
    db.Column("blocker_id", db.Integer, db.ForeignKey("users.id")),
    db.Column("blockee_id", db.Integer, db.ForeignKey("users.id")),
    db.UniqueConstraint("blocker_id", "blockee_id")
)


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.Text(), unique=True)
    email = db.Column(db.Text())
    password = db.Column(db.String(66))
    active = db.Column(db.Boolean(), default=True)
    api_key = db.Column(db.String(16))

    following = db.relation(
        "User",
        secondary=follows,
        primaryjoin=follows.c.follower_id == id,
        secondaryjoin=follows.c.followee_id == id,
        backref=db.backref("followers", lazy="dynamic"),
    )

    blocking = db.relation(
        "User",
        secondary=blocks,
        primaryjoin=blocks.c.blocker_id == id,
        secondaryjoin=blocks.c.blockee_id == id,
        backref=db.backref("blockers", lazy="dynamic"),
    )

    def __init__(self, username, password, email=None):
        self.username = username
        self.email = email
        self.set_password(password)
        self.gen_api_key()

    def set_password(self, pw):
        self.password = generate_password_hash(
            pw, method="pbkdf2:sha1:1000", salt_length=8
        )

    def check_password(self, pw):
        return check_password_hash(self.password, pw)

    def gen_api_key(self):
        self.api_key = gen_salt(16)


class Sup(db.Model):
    __tablename__ = "sups"

    id = db.Column(db.Integer, primary_key=True)
    lat = db.Column(db.Float)
    lng = db.Column(db.Float)
    when = db.Column(db.DateTime)
    seen = db.Column(db.Boolean, default=False)

    from_user_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    from_user = db.relationship(
        "User", backref=db.backref("sent_sups", lazy="dynamic",
                                   order_by=when),
        foreign_keys=from_user_id,
    )

    to_user_id = db.Column(db.Integer, db.ForeignKey("users.id"))
    to_user = db.relationship(
        "User", backref=db.backref("received_sups", lazy="dynamic",
                                   order_by=when),
        foreign_keys=to_user_id,
    )

    def __init__(self, from_user, to_user, lat, lng, when=None):
        # Check and update the user relationships.
        if from_user in to_user.blocking:
            raise SupBlockError()
        if to_user not in from_user.following:
            from_user.following.append(to_user)

        # Save the info.
        if when is None:
            when = datetime.utcnow()
        self.from_user = from_user
        self.to_user = to_user
        self.lat = lat
        self.lng = lng
        self.when = when
