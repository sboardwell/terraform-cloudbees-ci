.ONESHELL:
.DEFAULT_GOAL	:=  help
SHELL			:=  bash
MAKEFLAGS		+= --no-print-directory
MKFILE_DIR		:=  $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

ACTION ?= plan


.PHONY: %/p
%/p: ## Terraform plan on roots/%
	terraform -chdir=roots/$* plan -out tfplan

.PHONY: %/P
%/P: ## Terraform plan on roots/% (no planfile)
	terraform -chdir=roots/$* plan -out tfplan

.PHONY: %/a
%/a: ## Terraform apply on roots/%
	terraform -chdir=roots/$* apply tfplan

.PHONY: %/A
%/A: ## Terraform apply on roots/% (no plan, no approve)
	terraform -chdir=roots/$* apply -auto-approve

.PHONY: %/d
%/d: ## Terraform destroy on roots/%
	terraform -chdir=roots/$* destroy

.PHONY: %/D
%/D: ## Terraform destroy on roots/% (no plan, no approve)
	terraform -chdir=roots/$* destroy -auto-approve

.PHONY: %/o
%/o: ## Terraform output on roots/%
	terraform -chdir=roots/$* output

.PHONY: eks
eks: ## Run terraform $ACTION on roots/eks
	terraform -chdir=roots/eks $(ACTION)

.PHONY: sda
sda: ## Run terraform $ACTION on roots/sda
	terraform -chdir=roots/sda $(ACTION)

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then echo "Environment variable $* not set"; exit 1; fi
