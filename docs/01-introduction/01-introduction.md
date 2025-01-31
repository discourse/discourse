---
title: Introduction to Discourse Development
short_title: Introduction
id: introduction
---
Discourse is a modern and highly-customizable platform for building communities. This documentation is intended for anyone who wants to build a customization for Discourse, or work on Discourse itself.

## Architecture

**Discourse Core** is has a Ruby on Rails backend and an Ember JS frontend. This is the shared platform upon which Discourse communities are built.

**Discourse Themes** can be used to customize the frontend user experience using CSS and Javascript. Each theme has its own git repository, and community admins can generally install and manage them via the Discourse admin panel, even on shared hosting platforms.

**Theme Components** are themes which are intended for use alongside other Theme Components, as part of an overall Theme. From a development point of view, Theme Components and Themes are almost identical.

**Discourse Plugins** can customize the frontend in similar ways to themes. They can also customize the backend Ruby on Rails application, which allows them to introduce more extensive features. Plugins can only be installed by the server administrator, so their use may be restricted on shared hosting platforms.

## Getting Started

To work on Discourse Core, Themes or Plugins, you'll need a community to develop against.

To develop Themes or Theme Components, you can use the discourse_theme CLI against our public 'Theme Creator', your own production site, or a [dedicated development environment](https://meta.discourse.org/t/336366). Once you have a development environment, check out the [Theme Beginners Guide](https://meta.discourse.org/t/beginners-guide-to-developing-discourse-themes/93648).

To develop plugins or core, you'll need to set up a dedicated development environment. Once that's set up, check out the [Plugin Beginners Guide](https://meta.discourse.org/t/30515).

For general information about developing Discourse core, Themes and Plugins, check out the [Code Internals](https://meta.discourse.org/t/48891) section.

