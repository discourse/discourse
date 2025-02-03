---
title: Alternative icons
short_title: Alternative icons
id: alternative-icons
---

By default, Discourse bundles icons from the excellent [FontAwesome](https://fontawesome.com) library. But there are a lot of free-to-use icon libraries out there. This topic is the home of alternative icon sets. It lists some theme components that you can try now, but it also describes how you can contribute to have Discourse support other icon sets.

### Alternative icon sets

If you are interested in trying out a different icon set, here is a list of theme components that you can try out:

- https://github.com/discourse/discourse-feather-icons
- https://github.com/discourse/discourse-heroicons
- https://github.com/discourse/discourse-heroicons-outline
- https://github.com/discourse/discourse-phosphor-duotone-icons
- https://github.com/discourse/discourse-unicons
- https://github.com/discourse/discourse-material-design-icons-filled
- https://github.com/discourse/discourse-material-design-icons-outlined

(See [How to install a theme or theme component](https://meta.discourse.org/t/how-do-i-install-a-theme-or-theme-component/63682) for help getting one of these repos in your Discourse site.)

These components are a work in progress. You can use them, but note that not every single icon from core will have an appropriate replacement. (Contributions are welcome, though, see below.)

Some screenshots:

![image|690x438, 75%](/assets/alternative-icons-1.png)

**Feather icons** (using the WCAG Dark color scheme)

---

![image|690x459, 75%](/assets/alternative-icons-2.png)

**Heroicons** (using the WCAG Light color scheme)

---

![image|689x500, 75%](/assets/alternative-icons-3.png)

**Unicons** (using the Grey Amber color scheme)

---

![image|687x500, 75%](/assets/alternative-icons-4.png)

**Phosphor Duotone** (using the WCAG Light color scheme)

### Contributing

_Theme developers and designers, this section is for you._

The components listed above are generated using the [discourse-alt-icons](https://github.com/discourse/discourse-alt-icons) utility repository, which streamlines replacing icons in Discourse core with icons from other open source icon sets. The heart of the repository is a build script that generates a theme component from a JSON file of icon name mappings.

**Contributions are welcome and encouraged.** Discourse uses many icons from FontAwesome and finding matches from other icon sets is a fun task, but it is time-consuming. If you want to help, you can pull the [discourse-alt-icons](https://github.com/discourse/discourse-alt-icons) and follow the steps in the readme to add matches for icons that don't yet have them.

### Supporting other icon sets

Please use the replies below to propose adding support for another icon set. Or, even better, with a little bit of work you can send a pull request to the [discourse-alt-icons](https://github.com/discourse/discourse-alt-icons) repository. Note, that only icon sets with very permissive licenses (i.e. must allow modification, distribution, private use) will be considered.
