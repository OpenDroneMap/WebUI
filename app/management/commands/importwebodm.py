import os
import subprocess
import time

from django.core.management.base import BaseCommand, CommandError
from django.db import connection

DEFAULT_NODE_NAME = 'node-odm-1'
LEGACY_NODE_NAME = 'node-odx-1'
ANONYMOUS_USER = 'AnonymousUser'


def pg_args(params):
    args = []
    if params.get('host'):
        args += ['-h', params['host']]
    if params.get('port'):
        args += ['-p', str(params['port'])]
    if params.get('user'):
        args += ['-U', params['user']]
    return args


def pg_env(params):
    env = os.environ.copy()
    if params.get('password'):
        env['PGPASSWORD'] = params['password']
    return env


def psql(params, sql, dbname=None):
    result = subprocess.run(['psql'] + pg_args(params) + ['-d', dbname or params['dbname'], '-tAc', sql],
                            env=pg_env(params), capture_output=True, text=True)
    if result.returncode != 0:
        raise CommandError("psql failed: {}".format(result.stderr.strip()))
    return result.stdout.strip()


def wait_for_database(params, timeout=120):
    deadline = time.monotonic() + timeout
    while True:
        try:
            psql(params, 'SELECT 1')
            return
        except CommandError:
            if time.monotonic() > deadline:
                raise
            time.sleep(2)


def table_count(target):
    return int(psql(target, "SELECT count(*) FROM pg_tables WHERE schemaname = 'public' AND tablename <> 'spatial_ref_sys'"))


def holds_user_data(target):
    """
    A WebUI database that has been started but never used holds only the
    schema and boot rows (theme, settings, default node, guardian's anonymous
    user). Anything the user created counts as data worth keeping.
    """
    try:
        rows = psql(target, "SELECT (SELECT count(*) FROM app_project) + (SELECT count(*) FROM app_task) + "
                            "(SELECT count(*) FROM auth_user WHERE username <> '{}')".format(ANONYMOUS_USER))
    except CommandError:
        return True
    return int(rows) > 0


def recreate_database(target):
    name = target['dbname']
    psql(target, 'DROP DATABASE "{}"'.format(name), dbname='postgres')
    psql(target, 'CREATE DATABASE "{}" TEMPLATE template1'.format(name), dbname='postgres')


def import_database(source, target, stdout=None):
    """
    Copy a WebODM database into a WebUI database that holds no user data.

    source and target are dicts with host, port, user, dbname and an optional
    password. Both servers may still be starting up.
    """
    wait_for_database(source)
    wait_for_database(target)
    if table_count(target) > 0:
        if holds_user_data(target):
            raise CommandError("The target database {} already contains projects, tasks or users. Import only into an unused installation.".format(target['dbname']))
        recreate_database(target)

    dump = subprocess.Popen(['pg_dump'] + pg_args(source) + ['--no-owner', '--no-acl', '--exclude-schema=topology', source['dbname']],
                            env=pg_env(source), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    restore = subprocess.Popen(['psql'] + pg_args(target) + ['-d', target['dbname'], '-q', '-o', os.devnull,
                                                           '-v', 'ON_ERROR_STOP=1', '--single-transaction'],
                               env=pg_env(target), stdin=dump.stdout, stderr=subprocess.PIPE)
    dump.stdout.close()
    restore_err = restore.stderr.read()
    restore.wait()
    dump_err = dump.stderr.read()
    dump.wait()
    if restore.returncode != 0:
        raise CommandError("restore failed: {}".format(restore_err.decode(errors='replace').strip()))
    if dump.returncode != 0:
        raise CommandError("pg_dump failed: {}".format(dump_err.decode(errors='replace').strip()))

    for column in ('hostname', 'label'):
        psql(target, "UPDATE nodeodm_processingnode SET {0} = '{1}' WHERE {0} = '{2}'".format(column, DEFAULT_NODE_NAME, LEGACY_NODE_NAME))

    if stdout is not None:
        for table, label in (('auth_user', 'users'), ('app_project', 'projects'), ('app_task', 'tasks'), ('nodeodm_processingnode', 'processing nodes')):
            stdout.write("{}: {}".format(label, psql(target, "SELECT count(*) FROM {}".format(table))))


class Command(BaseCommand):
    help = "Copy the database of a WebODM installation into this unused database. The source password is read from PGPASSWORD or ~/.pgpass."
    requires_system_checks = []

    def add_arguments(self, parser):
        parser.add_argument("--host", type=str, required=True, help="Host of the WebODM postgres server")
        parser.add_argument("--port", type=int, default=5432, help="Port of the WebODM postgres server")
        parser.add_argument("--user", type=str, default="postgres", help="User of the WebODM postgres server")
        parser.add_argument("--dbname", type=str, default="webodm_dev", help="Name of the WebODM database")
        super().add_arguments(parser)

    def handle(self, **options):
        source = {
            'host': options['host'],
            'port': options['port'],
            'user': options['user'],
            'dbname': options['dbname'],
        }
        db = connection.settings_dict
        target = {
            'host': db['HOST'],
            'port': db['PORT'],
            'user': db['USER'],
            'password': db['PASSWORD'],
            'dbname': db['NAME'],
        }
        import_database(source, target, self.stdout)
