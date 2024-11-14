---
title: Install Discourse for development using Docker
short_title: Docker setup
id: docker-setup

---
<div data-theme-toc="true"> </div>

# Developing using Docker

Since Discourse runs in Docker, you should be able to run Discourse directly from your source directory using a Discourse development container. 

 :white_check_mark: Pros: No need to install any system dependencies, no configuration needed at all for setting up a development environment quickly.

:x: Cons: Will be slightly slower than the native dev environment on Ubuntu, and much slower than a native install on MacOS.

## Step 1: Install Docker
### Ubuntu

```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
```
19.10
```
sudo apt-get install docker.io
sudo usermod -a -G docker $USER
sudo reboot
```

#### Windows WSL: Ubuntu
You can run the above commands within WSL but you **must** have all the files inside WSL file system. E.g. it works just fine if it's inside `~/discourse` but it fails if it's placed inside `/mnt/c/discourse`.

### MacOS

> :warning: The Discourse development docker image is only available for x86_64 architectures. M1 Macs are capable of starting the image using architecture emulation, but Discourse is unlikely to boot due to the [lack of inotify support](https://github.com/discourse/discourse/pull/13117) in QEMU. 
> 
> Instead, you should use https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-macos-for-development/15772

_Option 1:_ Download a packaged `.dmg` from the [Docker store](https://store.docker.com/editions/community/docker-ce-desktop-mac)
_Option 2:_ `brew install docker`



## Step 2: Start Container
Clone Discourse repository to your local device.
```
git clone https://github.com/discourse/discourse.git
cd discourse
```

_(from your source root)_

```ruby
d/boot_dev --init
    # wait while:
    #   - dependencies are installed,
    #   - the database is migrated, and
    #   - an admin user is created (you'll need to interact with this)

# In one terminal:
d/rails s

# And in a separate terminal
d/ember-cli
```

... then open a browser on http://localhost:4200 and _voila!_, you should see Discourse.

## Plugin Symlinks

The Docker development flow supports symlinks under the `plugins/` directory, with the following caveat:

Whenever a new plugin symlink is created, the Docker container must be restarted with:

 ```sh
 d/shutdown_dev; d/boot_dev
 ```
---

**Notes:** 

- To test emails, run MailHog :

  ```sh
  d/mailhog
   ```

- If there are missing gems, run:

  ```sh
  d/bundle install
   ```

- If a db migration is needed:

  ```sh
  d/rake db:migrate RAILS_ENV=development
   ```

- When you're done, you can choose to kill the Docker container with:

  ```sh
  d/shutdown_dev
   ```


- Data is persisted between invocations of the container in your source root `tmp/postgres` directory. If for any reason you want to reset your database run:

   ```sh
   sudo rm -fr data
   ```


- If you see errors like "_permission denied while trying to connect to Docker_", Run:
  ```
  run `sudo usermod -aG docker ${USER}` 
  sudo service docker restart
  ```
- If you wish to globally expose the ports from the container to the network (default off) use:
  ```
  d/boot_dev -p
  ```
- The Dockerfile comes from [discourse/discourse_docker on GitHub](https://github.com/discourse/discourse_docker), in particular [image/discourse_dev](https://github.com/discourse/discourse_docker/tree/master/image/discourse_dev).

## Running Tests

```ruby
d/rake autospec
```

To run specific plugin tests, you can also do something like this:

```
d/rake plugin:spec["discourse-follow"]
```
Or even something like this to be even more specific:

```
my-machine:~/discourse$ d/shell
discourse@discourse:/src$ LOAD_PLUGINS=1 RAILS_ENV=test /src/bin/rspec plugins/discourse-follow/spec/lib/updater_spec.rb:37
```
