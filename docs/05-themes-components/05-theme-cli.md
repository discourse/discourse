---
title: Install the Discourse Theme CLI console app to help you build themes
short_title: Theme CLI
id: theme-cli

---
The [![discourse|180x180,10%](/assets/theme-cli-1.png) Discourse Theme CLI](https://github.com/discourse/discourse_theme) is a ruby gem that allows you to use your editor of choice when developing Discourse themes and theme components. As you save files the CLI will update the remote theme or component and changes to it will appear live!

## Installing

To play with it, make sure you have **Ruby 2.5** or up installed. 

![image|500x500,10%](/assets/theme-cli-2.png) 

If you are on Windows, you have 2 options:

**Option 1**:  [Windows Subsystem for Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux). 

Windows 10 has access to a full Linux environment, you can use it to install ruby simply with `sudo apt-get install ruby`, this will give you Ruby 2.3. 

**Options 2**: Older Windows

Older versions of Windows have no access to WSL, you can easily install Ruby with [Ruby Installer](https://rubyinstaller.org/), go for the recommended version and default settings for the install. 

![image|225x225,30%](/assets/theme-cli-3.png)

Mac OS version 10.13.3 ship with Ruby 2.3 out of the box, nothing special is needed. If you are running an earlier version of Mac OS consider using [rvm](https://rvm.io/rvm/install), [rbenv](https://github.com/rbenv/rbenv) or [homebrew](https://brew.sh/) to install a recent ruby.

----

Once Ruby 2.2 or later is running, open a terminal or command shell and run:

```text
gem install discourse_theme
```

Once installed, to learn more about it:

```text
discourse_theme
```

## Upgrading 

```
gem update discourse_theme
```

## Features

The CLI provides 3 main functions:

### discourse_theme new

You can use it to quickly create a new theme with `discourse_theme new YOUR_DIR_NAME`

### discourse_theme watch

 You can use it to monitor a theme and **synchronize** with a discourse site (with live refresh) using `discourse_theme watch YOUR_DIR_NAME` 

What this means is that you can use **your own editor** to edit you theme and site will magically :unicorn:  update with the changes!

### discourse_theme download

You can download an existing theme from Discourse using `discourse_theme download YOUR_DIR_NAME`. You will then be given the option to start "watching" straight away!

## Credentials

You will need to generate an API Key. Go to the admin area and generate a key there.

- :exclamation: Select a “User Level” of `Single User` when generating the key, not `All Users` .
- :exclamation: Make sure to check `Global Key` or you will receive 403 forbidden errors.

Credentials are (optionally) stored at `~/.discourse_theme`. API keys are stored per-site, and the URL/theme_id for each directory is also tracked. If you ever need to change your settings, just add `--reset` to any command and you will be prompted for all values again.

## Testimonials

"This tool is truly a GEM!" @awole20
"This is very very good." @awesomerobot 
"It’s working :) And it’s pretty dosh garn cool. Nice!" @angus
"OMG. It's unbelievable." @pfaffman
