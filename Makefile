export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION = us-east-1
SHELL := /bin/bash

usage:		## Show this help
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

install:	## Install dependencies
	@which lstk || npm install -g @localstack/lstk
	npm ci

start:		## Start LocalStack
	@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) lstk start

stop:		## Stop LocalStack
	@lstk stop

deploy:		## Deploy the service to LocalStack
	npx serverless deploy --stage local

test:		## Create, read, update and delete a todo through the API
	./test.sh

remove:		## Remove the service from LocalStack
	npx serverless remove --stage local

.PHONY: usage install start stop deploy test remove
