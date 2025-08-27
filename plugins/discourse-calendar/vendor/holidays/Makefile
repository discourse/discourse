default: test

setup: update-defs
	bundle install

generate:
	bundle exec rake generate

test:
	bundle exec rake test

console:
	bundle exec rake console

test-region:
	bundle exec rake test_region $(REGION)

build: clean
	bundle exec gem build holidays.gemspec

push:
	bundle exec gem push $(GEM)

update-defs: definitions/
	git submodule update --init --remote --recursive

definitions: point-to-defs-master

point-to-defs-branch:
	git submodule add -b $(BRANCH) git@github.com:$(USER)/definitions.git definitions/

point-to-defs-master:
	git submodule add https://github.com/holidays/definitions definitions/

clean-defs:
	git rm -f definitions
	rm -rf .git/modules/definitions
	git config -f .git/config --remove-section submodule.definitions 2> /dev/null

clean:
	rm -rf holidays-*.gem
	rm -rf reports
	rm -rf coverage

.PHONY: setup test generate console build push update-defs test-region clean-defs point-to-defs-master point-to-defs-branch clean definitions
