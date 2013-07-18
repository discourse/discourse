# Contributing to Discourse

## Before You Start

Anyone wishing to contribute to the **[Discourse/Discourse](https://github.com/discourse/discourse)** project **MUST read & sign the [Electronic Discourse Forums Contribution License Agreement](http://www.discourse.org/cla)**. The Discourse team is legally prevented from accepting any pull requests from users who have not signed the CLA first.

## Reporting Bugs

1. Always update to the most recent master release; the bug may already be resolved.

2. Search for similar issues on the [Discourse meta forum][m]; it may already be an identified problem.

3. Make sure you can reproduce your problem on our sandbox at [try.discourse.org](http://try.discourse.org)

4. If this is a bug or problem that **requires any kind of extended discussion -- open [a topic on meta][m] about it**. Do *not* open a bug on GitHub.

5. If this is a bug or problem that is clear, simple, and is unlikely to require *any* discussion -- it is OK to open an [issue on GitHub](https://github.com/discourse/discourse/issues) with a reproduction of the bug including workflows, screenshots, or links to examples on [try.discourse.org](http://try.discourse.org). If possible, submit a Pull Request with a failing test. If you'd rather take matters into your own hands, fix the bug yourself (jump down to the "Contributing (Step-by-step)" section).

6. When the bug is fixed, we will do our best to update the Discourse topic or GitHub issue with a resolution.

## Requesting New Features

1. Do not submit a feature request on GitHub; all feature requests on GitHub will be closed. Instead, visit the **[Discourse meta forum, features category](http://meta.discourse.org/category/feature)**, and search this list for similar feature requests. It's possible somebody has already asked for this feature or provided a pull request that we're still discussing.

2. Provide a clear and detailed explanation of the feature you want and why it's important to add. The feature must apply to a wide array of users of Discourse; for smaller, more targeted "one-off" features, you might consider writing a plugin for Discourse. You may also want to provide us with some advance documentation on the feature, which will help the community to better understand where it will fit.

3. If you're a Rock Star programmer, build the feature yourself (refer to the "Contributing (Step-by-step)" section below).

## Contributing (Step-by-step)

1. Clone the Repo:

        git clone git://github.com/discourse/discourse.git  

2. Create a new Branch:
 
        cd discourse
        git checkout -b new_discourse_branch

3. Code
  * Adhere to common conventions you see in the existing code
  * Include tests, and ensure they pass
  * Search to see if your new functionality has been discussed on [the Discourse meta forum](http://meta.discourse.org), and include updates as appropriate

4. Follow the Coding Conventions
  * two spaces, no tabs
  * no trailing whitespaces, blank lines should have no spaces
  * use spaces around operators, after commas, colons, semicolons, around `{` and before `}`
  * no space after `(`, `[` or before `]`, `)`
  * use Ruby 1.9 hash syntax: prefer `{ a: 1 }` over `{ :a => 1 }`
  * prefer `class << self; def method; end` over `def class.method` for class methods
  * prefer `{ ... }` over `do ... end` for single-line blocks, avoid using `{ ... }` for multi-line blocks
  * avoid `return` when not required

  > However, please note that **pull requests consisting entirely of style changes are not welcome on this project**. Style changes in the context of pull requests that also refactor code, fix bugs, improve functionality *are* welcome.

5. Commit
 
  First, ensure that if you have several commits, they are **squashed into a single commit**:

  ```
  git remote add upstream https://github.com/discourse/discourse.git
  git fetch upstream
  git checkout new_discourse_branch
  git rebase upstream/master
  git rebase -i

  < Choose 'squash' for all of your commits except the first one. >
  < Edit the commit message to make sense, and describe all your changes. >

  git push origin new_discourse_branch -f
  ```

  Now you're ready to commit:

  ```
  git commit -a
  ```

  **NEVER leave the commit message blank!** Provide a detailed, clear, and complete description of your commit!


6. Update your branch

  ```
  git checkout master
  git pull --rebase
  ```

7. Fork

  ```
  git remote add mine git@github.com:<your user name>/discourse.git
  ```

8. Push to your remote

  ```
  git push mine new_discourse_branch
  ```

9. Issue a Pull Request

  In order to make a pull request,
  * Navigate to the Discourse repository you just pushed to (e.g. https://github.com/your-user-name/discourse)
  * Click "Pull Request".
  * Write your branch name in the branch field (this is filled with "master" by default)
  * Click "Update Commit Range".
  * Ensure the changesets you introduced are included in the "Commits" tab.
  * Ensure that the "Files Changed" incorporate all of your changes.
  * Fill in some details about your potential patch including a meaningful title.
  * Click "Send pull request".
  
  Thanks for that -- we'll get to your pull request ASAP, we love pull requests!

10. Responding to Feedback

  The Discourse team may recommend adjustments to your code. Part of interacting with a healthy open-source community requires you to be open to learning new techniques and strategies; *don't get discouraged!* Remember: if the Discourse team suggest changes to your code, **they care enough about your work that they want to include it**, and hope that you can assist by implementing those revisions on your own.
  
[m]: http://meta.discourse.org
