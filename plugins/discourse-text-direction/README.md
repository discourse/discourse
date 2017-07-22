discourse-text-direction
========================

A Discourse plugin for setting the text direction in a post.

Usage
-----
In your posts, surround text with `[text-direction=rtl]` and `[/text-direction]`
for right-to-left text or `[text-direction=ltr]` and `[/text-direction]` for
left-to-right text.

Installation
============
* Add the plugin's repo url to your container's yml config file

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/scossar/discourse-text-direction
```

* Rebuild the container

```shell
cd /var/docker
git pull
./launcher rebuild app
```

* Re-render all posts now that the plugin is installed. This won't create any extra revisions.

```shell
rake posts:rebake
```

Customize
=========
The plugin tags add the class `tmp-rtl` for right-to-left text and the class `tmp-ltr` for left-to-right
text. To customize the output add custom css rules for those classes to your site in
admin/customize/css_html.
