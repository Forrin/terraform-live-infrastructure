.PHONY: all test init apply
all: test init apply

.PHONY: plan
plan:
	@terraform plan -var "do_token=$${DO_PAT}"

.PHONY: apply
apply:
	@terraform apply -var "do_token=$${DO_PAT}"

.PHONY: destroy
destroy:
	@terraform destroy -var "do_token=$${DO_PAT}"

.PHONY: init
init:
	@terraform init
	@terraform get --update

.PHONY: test
test:
	@terraform fmt
	@terraform init
	@terraform validate
