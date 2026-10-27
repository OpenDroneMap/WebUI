from django.contrib.auth.models import User
from django.core.management.base import CommandError
from django.db import connection
from django.test import TransactionTestCase

from app.management.commands.importwebodm import import_database, psql
from app.models import Project
from nodeodm.models import ProcessingNode


class TestImportWebODM(TransactionTestCase):
    """
    Uses the test database as the WebODM source and a scratch database,
    created from template1 like the real one, as the WebUI target.
    """
    target_name = 'test_importwebodm_target'

    def pg_params(self, dbname):
        db = connection.settings_dict
        return {
            'host': db['HOST'],
            'port': db['PORT'],
            'user': db['USER'],
            'password': db['PASSWORD'],
            'dbname': dbname,
        }

    def setUp(self):
        with connection.cursor() as c:
            c.execute('DROP DATABASE IF EXISTS {}'.format(self.target_name))
            c.execute('CREATE DATABASE {} TEMPLATE template1'.format(self.target_name))
        self.source = self.pg_params(connection.settings_dict['NAME'])
        self.target = self.pg_params(self.target_name)

        user = User.objects.create_user(username='webodm', email='w@o.dm', password='x')
        Project.objects.create(owner=user, name='Imported project')
        ProcessingNode.objects.create(hostname='node-odx-1', port=3000, label='node-odx-1')

    def tearDown(self):
        with connection.cursor() as c:
            c.execute('DROP DATABASE IF EXISTS {}'.format(self.target_name))

    def assertImported(self):
        self.assertEqual(psql(self.target, "SELECT name FROM app_project"), 'Imported project')
        self.assertEqual(psql(self.target, "SELECT hostname || ' ' || label FROM nodeodm_processingnode"), 'node-odm-1 node-odm-1')
        self.assertEqual(psql(self.target, "SELECT count(*) FROM auth_user WHERE username = 'webodm'"), '1')

    def test_import_into_empty_database(self):
        import_database(self.source, self.target)
        self.assertImported()

    def test_import_replaces_unused_database(self):
        # A started but unused WebUI database: tables, boot rows, no user data
        psql(self.target, "CREATE TABLE app_project (id int); CREATE TABLE app_task (id int); "
                          "CREATE TABLE auth_user (username text); INSERT INTO auth_user VALUES ('AnonymousUser'); "
                          "CREATE TABLE app_theme (id int); INSERT INTO app_theme VALUES (1)")
        import_database(self.source, self.target)
        self.assertImported()

    def test_import_refuses_database_with_user_data(self):
        import_database(self.source, self.target)
        with self.assertRaises(CommandError):
            import_database(self.source, self.target)
        self.assertImported()
