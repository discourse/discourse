CONTRIBUTING
============

Submitting a Pull Request
-------------------------

1. [Fork the repository][fork].
2. [Create a topic branch][branch] (`git checkout -b BRANCH_NAME`).
3. [Install bundler][bundler].
4. Check that tests pass with `rspec spec`.
5. Write a failing test to capture existing bug or lack of feature.
6. Run `rspec spec` to verify that test fails.
7. Implement your feature or bug fix.
8. Ensure tests pass.
9. If it's a new feature or a bug fix, please add an entry to the CHANGELOG file.
10. Check code style violations using [Rubocop][rubocop].
11. Add a commit (`git commit -am 'AWESOME COMMIT MESSAGE'`).
12. Push your changes to the branch (`git push origin BRANCH_NAME`).
13. [Submit a pull request.][pr]
14. You will get some feedback and may need to push additional commits
    with more fixes to the same branch; this will update your pull request
    automatically.

[branch]: http://git-scm.com/book/en/Git-Branching-Branching-Workflows#Topic-Branches
[bundler]: http://bundler.io
[fork]: https://help.github.com/articles/fork-a-repo/
[pr]: https://help.github.com/articles/using-pull-requests
[rubocop]: https://github.com/bbatsov/rubocop
