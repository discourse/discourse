.PHONY: pull update migrate help

help:
	@echo usage:
	@echo '  make pull    → pull new code and update dependencies'
	@echo '  make migrate → run migrations'
	@echo '  make update  → pull and run migrations'

pull:
	git pull
	yarn
	bundle

migrate:
	LOAD_PLUGINS=1 bin/rails db:migrate
	LOAD_PLUGINS=1 bin/rails db:migrate RAILS_ENV=test

update: pull migrate
