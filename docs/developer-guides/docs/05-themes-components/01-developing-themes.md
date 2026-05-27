---
title: Developing Discourse Themes & Theme Components
short_title: Developing Themes
id: beginners-guide
---

Discourse Themes and Theme Components can be used to customize the look, feel and functionality of Discourse's frontend. This section of the developer guides aims to provide all the reference materials you need to develop simple themes for a single site, right up to complex open-source theme components.

This introduction aims to provide a map of all the tools and APIs for theme development. If you prefer a step-by-step tutorial for theme development, jump straight to:

https://meta.discourse.org/t/theme-developer-tutorial-1-introduction/357796

## Themes vs. Theme Components

**Discourse Themes** can be used to customize the frontend user experience using CSS and JavaScript. Each theme has its own git repository, and community admins can generally install and manage them via the Discourse admin panel, even on shared hosting platforms.

**Theme Components** are themes which are intended for use alongside other Theme Components, as part of an overall Theme. From a development point of view, Theme Components and Themes are almost identical. In these guides, the phrase "Theme" and "Theme Component" are used interchangeably.

## Prerequisites

Firstly, make sure you understand [how to use existing themes and theme components](https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966) in Discourse. Using ready-made themes is the quickest and safest way to customize your community. If you need more, then it's time to consider writing your own theme.

As part of [Discourse's overall architecture](https://meta.discourse.org/t/349939), Discourse Themes are built using standard HTML, CSS, JavaScript technologies, and make use of Ember concepts for more advanced UIs. These reference guides assume a base-level understanding of these technologies, and link out to external references where possible.

Discourse is a fast-moving project, and as such any custom theme will [require maintenance over time](https://meta.discourse.org/t/261388). Make sure you consider this as part of your planning & development processes.

## Getting Started

- [Theme CLI](https://meta.discourse.org/t/install-the-discourse-theme-cli-console-app-to-help-you-build-themes/82950)
- [Theme Creator](https://meta.discourse.org/t/get-started-with-theme-creator-and-the-theme-cli/108444)
- [File structure of theme](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848)

## Frontend Customization

- [Color Schemes](https://meta.discourse.org/t/61196)
- [JavaScript API](https://meta.discourse.org/t/41281)
- [Outlets](https://meta.discourse.org/t/32727)
- [Transformers](https://meta.discourse.org/t/349954)
- [modifyClass](https://meta.discourse.org/t/262064)

## More!

Check out the rest of the [Developer Guides](https://meta.discourse.org/c/documentation/developer-guides/56) !
