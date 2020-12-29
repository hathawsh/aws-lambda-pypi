
default: out/lambda_pypicloud.zip

out/lambda_pypicloud.zip: Dockerfile lambda_function.py
	mkdir -p out && \
	DOCKER_BUILDKIT=1 docker build -o out .

.PHONY: default
