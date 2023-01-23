.ONESHELL:
.DEFAULT_GOAL	:=  help
SHELL			:=  bash
MAKEFLAGS		+= --no-print-directory
MKFILE_DIR		:=  $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ACTION ?= plan


.PHONY: eks
eks: ## Run terraform $ACTION on roots/eks
	terraform -chdir=roots/eks $(ACTION)

.PHONY: sda
sda: ## Run terraform $ACTION on roots/sda
	terraform -chdir=roots/sda $(ACTION)

.PHONY: %/i
%/i: ## Run terraform init on roots/%
	terraform -chdir=roots/$* init

.PHONY: %/iu
%/iu: ## Run terraform init -upgrade on roots/%
	terraform -chdir=roots/$* init -upgrade

.PHONY: %/p
%/p: ## Run terraform plan on roots/%
	terraform -chdir=roots/$* plan -out tfplan

.PHONY: %/P
%/P: ## Run terraform plan on roots/% (no planfile)
	terraform -chdir=roots/$* plan

.PHONY: %/a
%/a: ## Run terraform apply on roots/%
	terraform -chdir=roots/$* apply tfplan

.PHONY: %/A
%/A: ## Run terraform apply on roots/% (auto-approve)
	terraform -chdir=roots/$* apply -auto-approve

.PHONY: %/d
%/d: ## Run terraform destroy on roots/%
	terraform -chdir=roots/$* destroy

.PHONY: %/D
%/D: ## Run terraform destroy on roots/% (auto-approve)
	terraform -chdir=roots/$* destroy -auto-approve

.PHONY: %/r
%/r: ## Terraform output on roots/%
	terraform -chdir=roots/$* refresh

.PHONY: %/o
%/o: ## Run terraform output on roots/%
	terraform -chdir=roots/$* output

.PHONY: %/O
%/O: ## Run terraform output on roots/% (json format)
	terraform -chdir=roots/$* output -json

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then echo "Environment variable $* not set"; exit 1; fi
