
import lambda_venv_path  # noqa

import boto3
import json
import os
from paste.deploy import loadapp
from apig_wsgi import make_lambda_handler


ini_template = """
[app:main]
use = egg:pypicloud
pyramid.reload_templates = False
pyramid.debug_authorization = false
pyramid.debug_notfound = false
pyramid.debug_routematch = false
pyramid.default_locale_name = en
pypi.default_read = authenticated
pypi.storage = s3
storage.bucket = {BUCKET}
storage.region_name = {BUCKET_REGION}
pypi.db = dynamo
db.region_name = {DYNAMO_REGION}
pypi.auth = pypicloud.access.aws_secrets_manager.AWSSecretsManagerAccessBackend
auth.secret_id = {AUTH_SECRET_ID}
session.encrypt_key = {SESSION_ENCRYPT_KEY}
session.validate_key = {SESSION_VALIDATE_KEY}
session.secure = True
session.invalidate_corrupt = true
pypi.fallback = redirect

[loggers]
keys = root

[handlers]
keys = stdout

[formatters]
keys = generic

[logger_root]
level = INFO
handlers = stdout

[handler_stdout]
class = StreamHandler
args = (sys.stdout,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)s %(asctime)s [%(name)s] %(message)s
"""


def generate_secret():
    import base64
    import secrets
    return base64.encodebytes(secrets.token_bytes(32)).decode('ascii').strip()


def get_config_fn():
    """Get the environment overlay file from Secrets Manager"""
    env_overlay = {}

    secret_id = os.environ.get('ENV_SECRET_ID')
    if secret_id:
        # Get or create the session encrypt and validate secrets.
        session = boto3.session.Session()
        client = session.client('secretsmanager')

        try:
            response = client.get_secret_value(SecretId=secret_id)
            env_overlay = json.loads(response['SecretString'])
        except client.exceptions.ResourceNotFoundException:
            env_overlay = {
                'SESSION_ENCRYPT_KEY': generate_secret(),
                'SESSION_VALIDATE_KEY': generate_secret(),
            }
            client.put_secret_value(
                SecretId=secret_id,
                SecretString=json.dumps(env_overlay),
            )

    env = {}
    env.update(os.environ)
    env.update({
        'SESSION_ENCRYPT_KEY': env_overlay['SESSION_ENCRYPT_KEY'],
        'SESSION_VALIDATE_KEY': env_overlay['SESSION_VALIDATE_KEY'],
    })
    ini_content = ini_template.format(**env)

    fn = '/tmp/server.ini'
    with open(fn, 'w') as f:
        f.write(ini_content)

    return fn


config_fn = get_config_fn()
app = loadapp(f'config:{config_fn}')
lambda_handler = make_lambda_handler(app)
