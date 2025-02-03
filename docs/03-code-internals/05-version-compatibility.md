---
title: Pinning plugin and theme versions for older Discourse installs (.discourse-compatibility)
short_title: Version compatibility
id: version-compatibility
---

### 📖 Background

Sometimes themes/plugins need to make changes which are only compatible with the latest version of Discourse. In that situation, older versions of Discourse can be instructed to use an older 'pinned' version of the plugin.

This is achieved using a `.discourse-compatibility` file in the root of a theme/plugin repository. It's a YAML file where keys specify the Discourse core version, and the values represent the associated version of your theme/plugin.

Discourse core versions can be specified using the `<=` and `<` operators. `<=` is the default for historical reasons, but generally it makes more sense to use `<`.

### 📌 Pinning a theme/plugin version

For example, if Discourse core makes a change during `3.2.0.beta2-dev` (found in version.rb) and your plugin/theme starts depending on it, then you would add an entry to the `.discourse-compatibility` file like this:

```yaml
< 3.2.0.beta2-dev: abcde
```

where `abcde` is a reference to the 'legacy' commit hash of YOUR PLUGIN which should be used on older versions of Discourse.

Now anyone using an older version of Discourse (e.g. `3.2.0.beta1`, or `3.1.4`) will use version `abcde` of your theme/plugin. Anyone on `3.2.0.beta2-dev` or above will continue using the latest version.

### 📋 Multiple Entries

Over time, you can add multiple lines to the `.discourse-compatibility` file. Discourse will always choose the 'lowest' specification which matches the current Discourse core version. The order of the lines in the file doesn't technically matter, but we recommend putting the newest entries at the top.

### :git_merged: 'Backporting' changes for old Discourse versions

Let's imagine a `.discourse-compatibility` file like this, with two different version specifications pinned to specific plugin commits:

```yaml
< 3.2.0.beta1-dev: commithashfordiscourse31
< 3.1.0.beta1-dev: commithashfordiscourse30
```

If you need to 'backport' a change to Discourse 3.1, you'd do something like:

1. Create a branch from the old commit (`git checkout -b my_branch_name commithashfordiscourse31`)

2. Commit your change and push to the origin. If you use GitHub's branch protection features, you may want to protect this branch from accidental deletion

3. Update the `.discourse-compatibility` file **on the main branch** so that it now points to your new commit on the 3.1 support branch

### 🌍 Real-World Example

Here's a real `.discourse-compatibility` file from the discourse-solved plugin. Note that, at the time of writing, this still uses the 'legacy' syntax without any explicit `<` or `<=` operators. Therefore, each line is automatically interpreted as `<=`.

https://github.com/discourse/discourse-reactions/blob/main/.discourse-compatibility
