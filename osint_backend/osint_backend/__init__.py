# ============================================================
# osint_backend/__init__.py
# PyMySQL shim: makes Django's MySQL backend use PyMySQL
# instead of mysqlclient (no C extension required).
# This MUST be here so it's loaded before Django configures
# the database connections.
# ============================================================
# import pymysql
# pymysql.install_as_MySQLdb()
