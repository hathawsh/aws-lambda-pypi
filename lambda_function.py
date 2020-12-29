
import lambda_venv_path  # noqa

import boto3
import os
from paste.deploy import loadapp
from apig_wsgi import make_lambda_handler


def get_config_fn():
    """Get the config file from Secrets Manager"""
    secret_id = os.environ['PYPICLOUD_CONF_SECRET_ID']
    region = os.environ['PYPICLOUD_CONF_REGION']

    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region,
    )

    fn = '/tmp/server.ini'
    response = client.get_secret_value(SecretId=secret_id)
    with open(fn, 'w') as f:
        f.write(response['SecretString'])

    return fn


config_fn = get_config_fn()
app = loadapp(f'config:{config_fn}')
lambda_handler = make_lambda_handler(app)
