# PyPICloud + AWS Lambda + Terraform

This project brings together a few pieces so you can easily run a small
PyPICloud instance as an AWS Lambda function with the help of Terraform.
PyPICloud lets you publish Python packages privately, AWS Lambda lets you run
a small service for free, and Terraform ensures the service is deployed and
maintained correctly.

## Prerequisites

This project was tested in Ubuntu 20.04. It may work in other environments.
Feel free to submit issues.

The following software should be installed before you start:

- Docker (command line)
- The AWS CLI - https://aws.amazon.com/cli/
- Terraform
- Make (optional)

Note that this project only uses Docker for building a ZIP file and does not
use Docker in production. Some of the Python libraries contain native code
that must be compiled in the same type of environment where the code will run.
Docker makes it possible to ensure the build environment matches the AWS
Lambda environment.

## Build

`git clone` this project and `cd` to it. If you have `make` installed, type
`make`. If not, type:

```sh
mkdir -p out && DOCKER_BUILDKIT=1 docker build -o out .
```

The file `out/lambda_pypicloud.zip` will be generated. The zip file contains
all the Python code and libraries needed for the service. See `Dockerfile` and
`lambda_function.py` if you're interested in a simple way to run a Python app
on AWS Lambda.

## Authenticate to AWS

See:
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html

If you have logged in before, use `aws sts get-caller-identity` to find out
who you're currently authenticated as. If you manage mutiple AWS profiles, see
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html .

## Configure Deployment

Terraform needs some variable settings. In the `tf` folder, create a text file
with a name ending with `.auto.tfvars`. An example:

```sh
vim tf/my.auto.tfvars
```

Your `.auto.tfvars` file needs to set the `region`, `package_bucket`, and
`log_group` variables. The following template is a start, but replace the
bucket name `MY-PYPICLOUD-BUCKET` with a bucket name of your choosing.

```
region = "us-east-1"
package_bucket = "MY-PYPICLOUD-BUCKET"
log_group = "pypicloud"
```

The bucket name must be globally unique and must not already exist (unless
you're already skilled with Terraform and you prefer to `terraform import`
the bucket instead.)

## Deploy

Once you have built the ZIP file, authenticated to AWS, and set the variables,
run Terraform to deploy.

```sh
cd tf
terraform init && terraform apply
```

When Terraform completes successfully, you'll have a lambda function and an
API gateway URL connected to it. Find the URL of the service by typing:

```
terraform show -no-color | grep invoke_url
```

Visit that URL in your browser. Add yourself as an administrator. Read the
PyPICloud documentation to learn how to use your private package index when
installing or publishing packages:

https://pypicloud.readthedocs.io/en/latest/topics/getting_started.html#installing-packages

At this point, you have a serverless PyPICloud instance. Unless you use the
service a lot, it will probably stay entirely within the AWS free tier, but
remember to set up AWS billing alerts to notify you of usage spikes.

## Custom Domain Name

It is simple to use your own domain name.

- Use AWS Certificate Manager to create a free certificate for the domain or
  subdomain where you want to host your package index.

- Visit the AWS console and find the API Gateway object called `pypicloud`.
  Visit the *Custom domain names* link. Add your domain name and use the
  certificate you created. Enable TLS 1.2, but don't enable
  *Mutual TLS Authentication* unless you know how to create and use
  client certificates.

- Configure a CNAME in your DNS to map your domain or subdomain to the *API
  Gateway domain name* shown in the custom domain name's *Endpoint
  configuration* box. The API Gateway domain name is not the same as the
  DNS name used in the Invoke URL.

Terraform is not aware of the custom domain name setting unless you tell it
otherwise, so your domain name setting won't conflict with Terraform.

## Store Terraform State Remotely

You should store the Terraform state in an S3 bucket to ensure the state
doesn't get lost. Remote state storage is also important for working with a
team.

Create a new S3 storage bucket (or reuse one where you've already stored
Terraform state.) In the `tf` folder, create a file called `remote-state.tf`.
Use the following template, replaing `MY-TFSTATE-BUCKET` with the name of your
bucket:

```
terraform {
  backend "s3" {
    bucket = "MY-TFSTATE-BUCKET"
    key = "tfstate/pypicloud"
    region = "us-east-1"
  }
}
```

Run `terraform init` to migrate the local state to the storage bucket, then
use `terraform plan` to ensure Terraform is still working as intended.
