# Contributing to Discourse

## Before You Start

Anyone wishing to contribute to the **[Discourse/Discourse](https://github.com/discourse/discourse)** project **MUST read & sign the [Electronic Discourse Forums Contribution License Agreement](https://docs.google.com/a/discourse.org/spreadsheet/viewform?formkey=dGUwejFfbDhDYXR4bVFMRG1TUENqLWc6MQ)**. The Discourse team is legally prevented from accepting any pull requests from users who have not signed the CLA first.

## Reporting Bugs

1. Update to the most recent master release; the bug may already be resolved.

2. Search for similar issues on the Discourse development forums; it may already be an identified bug.

3. On GitHub, provide the details of the issue, with any included workflows, screenshots, or links to examples on jsfiddle.net. If possible, submit a Pull Request with a failing test. If you'd rather take matters into your own hands, fix the bug yourself (jump down to the "Contributing (Step-by-step)" section).

4. The Discourse team will work with you until your issue can be verified. Once verified, a team member will flag the issue appropriately, lock it, and create a new topic discussing the bug on the Discourse forums.

5. Continue to monitor the progress/discussion surrounding the bug by reading the topic assigned to your bug on the Discourse forums.

6. When the bug is fixed, the Discourse topic will be frozen, and the bug will be marked as fixed in the repo, with the appropriate commit assigned to the fix for tracking purposes.

## Requesting New Features

1. Do not submit a feature request on GitHub; all feature requests on GitHub will be closed. Instead, visit the Discourse development forums, and search for the "Feature Request" category, which will filter a list of outstanding requests. Review this list for similar feature requests. It's possible somebody has already asked for this feature or provided a pull request that we're still discussing.

2. Provide a clear and detailed explanation of the feature you want and why it's important to add. The feature must apply to a wide array of users of Discourse; for smaller, more targeted "one-off" features, you might consider writing a plugin for Discourse. You may also want to provide us with some advance documentation on the feature, which will help the community to better understand where it will fit.

3. If you're a Rock Star programmer, build the feature yourself (refer to the "Contributing (Step-by-step)" section below).

## Contributing (Step-by-step)

1. Clone the Repo:

  ```
  git clone git://github.com/discourse/discourse.git
  ```

2. Create a new Branch:

  ```
  cd discourse
  git checkout -b new_discourse_branch
  ```

3. Code

  Make some magic happen! Remember to:
  * Adhere to conventions.
  * Update CHANGELOG with a description of your work.
  * Include tests, and ensure they pass.
  * Remember to check to see if your new functionality has an impact on our Documentation, and include updates as appropriate.
  
  Completing these steps will increase the chances of your code making it into **[Discourse/Discourse](https://github.com/discourse/discourse)**.

4. Commit

  ```
  git commit -a
  ```

  **Do not leave the commit message blank!** Provide a detailed description of your commit!

  ### PRO TIP
 
  Ensure that if you supply a multitude of commits, they are **squashed into a single commit**:

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

5. Update your branch

  ```
  git checkout master
  git pull --rebase
  ```

6. Fork

  ```
  git remote add mine git@github.com:<your user name>/discourse.git
  ```

7. Push to your remote

  ```
  git push mine new_discourse_branch
  ```

8. Issue a Pull Request

  In order to make a pull request,
  * Navigate to the Discourse repository you just pushed to (e.g. https://github.com/your-user-name/discourse)
  * Click "Pull Request".
  * Write your branch name in the branch field (this is filled with "master" by default)
  * Click "Update Commit Range".
  * Ensure the changesets you introduced are included in the "Commits" tab.
  * Ensure that the "Files Changed" incorporate all of your changes.
  * Fill in some details about your potential patch including a meaningful title.
  * Click "Send pull request".
  
  Once these steps are done, you will soon receive feedback from The Discourse team!

9. Responding to Feedback

  The Discourse team may recommend adjustments to your code, and this is perfectly normal. Part of interacting with a healthy open-source community requires you to be open to learning new techniques and strategies; *don't get discouraged!* Remember: if the Discourse team suggest changes to your code, **they care enough about your work that they want to include it**, and hope that you can assist by implementing those revisions on your own.
