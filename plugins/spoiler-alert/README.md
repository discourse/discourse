# discourse-spoiler-alert

https://meta.discourse.org/t/discourse-spoiler-alert/12650/

Spoiler plugin for [Discourse](http://discourse.org) highly inspired by the [spoiler-alert](http://joshbuddy.github.io/spoiler-alert/) jQuery plugin.

## Usage

In your posts, surround text or images with `[spoiler]` ... `[/spoiler]`.
For example:

```
I watched the murder mystery on TV last night. [spoiler]The butler did it[/spoiler].
```

## Installation

- Add the plugin's repo url to your container's `app.yml` file

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/discourse/discourse-spoiler-alert.git
```

- Rebuild the container

```
cd /var/discourse
./launcher rebuild app
```

## License

MIT
