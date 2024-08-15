---
title: Use the `navigation_menu` query parameter to preview the sidebar or other options
short_title: Navigation menu
id: navigation-menu

---
If you are working on a theme for an existing site and want to preview how it will look with the sidebar or other options for the `navigation menu` site setting, you can use the `?navigation_menu` query parameter.

This feature is designed to help theme developers who want their theme to support all modes equally well, or for those who are working on their own site's theme to prepare for migration from one configuration to another.

To preview a site with different options, append the desired query parameter to the URL of a page:

- `?navigation_menu=sidebar`
- `?navigation_menu=header_dropdown`
- `?navigation_menu=legacy`

For example, you can try it out here on meta:

- <https://meta.discourse.org?navigation_menu=sidebar>
- <https://meta.discourse.org?navigation_menu=header_dropdown>
- <https://meta.discourse.org?navigation_menu=legacy>

The `navigation menu` site setting allows you to configure your main navigation menu to be a `sidebar`, a `header dropdown`, or the `legacy` hamburger menu, which was the only option available until the release of Discourse 3.0. Visit: https://meta.discourse.org/t/try-out-the-new-sidebar-and-notification-menus/238821 to read more about it.
