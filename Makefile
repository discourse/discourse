TEST_BRANCH = 'tests-passed'

# Delete the local branch 'tests-passed'
delete-test-branch-local:
	-git branch --delete $(TEST_BRANCH)

# Delete the remote branch 'tests-passed'
delete-test-branch-remote:
	-git push origin -d $(TEST_BRANCH)

# Delete the local and remote 'tests-passed' branch.
# Will log an expected error if the branch doesn't exists.
delete-test-branch: delete-test-branch-local delete-test-branch-remote

create-test-branch:
	git checkout -b $(TEST_BRANCH)
	git push -u origin $(TEST_BRANCH)

get-latest-tag:
	git describe --abbrev=0 --tags