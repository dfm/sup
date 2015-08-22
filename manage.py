#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

__all__ = ["manager"]

from flask.ext.script import Manager

from sup import create_app
from sup.manage import (
    CreateTablesCommand, DropTablesCommand,
    CreateUserCommand,
    SendSupCommand,
)

manager = Manager(create_app())
manager.add_command("create_tables", CreateTablesCommand())
manager.add_command("drop_tables", DropTablesCommand())

manager.add_command("create_user", CreateUserCommand())

manager.add_command("send_sup", SendSupCommand())

if __name__ == "__main__":
    manager.run()
