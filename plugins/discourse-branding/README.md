# [discourse-branding][codiss-category]

[![Discourse on Codiss][codiss-badge]][codiss-category]

## About

Add custom brand header with logo, navigation and icons for you Discourse website

## Screenshots

<img src="https://cdn.codiss.com/optimized/1X/4e728cd672cfc1b34f948dd1210bb7ca14488516_1_690x73.png" width="690" height="73">

<img src="https://cdn.codiss.com/optimized/1X/9e71e58393869d85eb4ac098473cb09911354ba2_1_690x293.png" width="690" height="293">

## Installation

Repo is at: https://github.com/vinkas0/discourse-branding

**[Navigation][plugin-navigation] plugin is required** to manage brand links and icons

In your `app.yml` add:

```
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/vinkas0/discourse-navigation.git
          - git clone https://github.com/vinkas0/discourse-branding.git
```

And then rebuild the container:

```
./launcher rebuild app
```

### Configuration

You can change branding settings under `admin/site_settings/category/branding`. And add your custom menu links in `/admin/plugins/navigation` path using [Navigation][plugin-navigation] plugin.



[plugin-navigation]: https://codiss.com/c/discourse-navigation

[codiss-category]: https://codiss.com/c/discourse-branding
[codiss-badge]: https://img.shields.io/badge/discourse-on_Codiss-blue.svg?style=flat-square
