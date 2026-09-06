# Maintainers guide

This document outlines the process of releasing an update of the definitions in this repository. Please note
that this document does NOT try to explain how to create packages for various languages. It is *just*
for creating version snapshots of definition files.

To be as clear as possible: this repository is *just* for definition updates. We 'release' updates as tags in Github
but do not push any code updates. Downstream projects (like ruby) will consume this and make their own appropriate releases.
The 'releases' in this project are mainly for organizational purposes.

### Who this document is for

This document is for maintainers that have merge access to this repository. Generally these people will also have access to any
language-specific libraries and so this will be a part of the entire release process. Usually other libraries (like the ruby library)
will reference this document as part of its own release process.

Please note that a core contributor must provide the relevant Github access so that you can perform merges. If you have any issues
please contact the [core members](https://github.com/orgs/holidays/teams/core/members) for assistance.

### Setup

This guide assumes that you have forked the repository in Github. If you require assistance in this please contact the core members listed above.

### Merging new definition changes

When new PRs are submitted you can navigate the following steps:

* Make sure that the PR Travis CI builds are green. If they are green then you can simply continue. If there are errors you
will need to investigate further (contact a core member for assistance).
* If the builds are green and the changes look reasonable to you then go ahead and merge!
* Once the merges are done, make a new branch on your fork that includes an updated [CHANGELOG](https://github.com/holidays/definitions/blob/master/CHANGELOG.md)
that has the new version and associated changes. This is pretty open-ended! Include the information that you feel is
important. Use past CHANGELOG updates as a guide.
* Open a PR against the CHANGELOG branch and merge it (this may require another maintainer for safety)
* Once the updated CHANGELOG is merged, go to [releases](https://github.com/holidays/definitions/releases) and create a new release. It should point at the latest commit that contains the changes that you want included in this release. If you just merged then you can just point at master.  All release versions follow this format: `vMAJOR.MINOR.PATCH`. This should follow normal [semver rules](https://semver.org/).

You don't need to list out the specific changes that were made on the release description. You can just give a general overview and then link to the updated CHANGELOG that you did in a previous step. Example: [v2.2.0](https://github.com/holidays/definitions/releases/tag/v2.2.0)

Once the release is created in Github you are done! The definitions have been 'released' and downstream projects (right now just ruby) can reference them without issues. See the maintainers guides in downstream projects for information on how to release updates for each language.
