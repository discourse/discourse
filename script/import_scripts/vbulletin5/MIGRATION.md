# Detailed Instructions for Migrating

**Caveat**: On the one hand, these are literally the commands I typed to do my migration. On the
other hand, they might not be exactly what you need. I tailored it heavily to my system, and I
didn't have several systems. So some code paths are poorly tested. I did not store any files in the
database (attachments, avatars), so the original code I based it on handled that, and I didn't
modify it, but I haven't tested it.

**Credits**: This is based on the original `vbulletin5.rb` and used some online sources. See credits
at the bottom of this file.

## Summary:
1. Install discourse and prep it
2. Get MariaDB setup
3. Pull attachments and avatars from live site, put them in `/shared/uploads`
4. Configure postgres for imports
5. Run `vbulletin5.rb` to import most stuff
6. Run `import_vb5_pm.rb` to pull in PMs
7. Run `import_vb5_avatars.rb` to import custom avatars
8. Shutdown postgres and switch to production config
9. Do post-migration adjustments

## Assumptions

* I assume you're doing the standard, quick install of Discourse, then customizing.
* I assume Discourse is in `/var/discourse`
* I assume your MariaDB database is called `vbforum`. If that's not it, adjust.

# Install Discourse

1. Run the easy installer to build the container

2. When you install **use a new email address** or **distinct userid** from the one you use on the
   VBulletin system. Otherwise, there will be 2 of you after migrating.
3. Stop the Discourse container (`sudo /var/discourse/launcher stop app`)
4. Edit your `/var/discourse/containers/app.yml`
5. Rebuild the container (`sudo /var/discourse/launcher rebuild app`)

## Prep Discourse

Assuming your Discourse is in `/var/discourse`, you'll see this pattern a lot. Enter the container, start the rails console, run some rails commands.

```sh
sudo /var/discourse/launcher enter app
rails console
```

Then run these commands at the rails console. This disables emails from going out (you don't want to
spam your users during the import). It prevents requiring admins to approve new users. If you don't
do that, then every imported user will be unable to login until they're approved by an admin. It
turns on the requirement to login. If your Discourse site is visible on the public internet, it
helps prevent bots and stuff from discovering and crawling your partially-imported site.

```ruby
SiteSetting.disable_emails = "yes"
SiteSetting.must_approve_users = false
SiteSetting.login_required = true
```

## Plugins

You probably want some plugins:

  - [discourse-bbcode](https://github.com/discourse/discourse-bbcode) if you have BBCode in your
    posts and you want Discourse to parse and render it.
  - [discourse-migratepassword](https://github.com/communiteq/discourse-migratepassword) so your
    users don't have to create new accounts or change their passwords.

The **discourse-migratepassword** plugin allows your migrated users to type their old VBulletin
password and get logged in to Discourse! It checks the password they type against the Discourse
native password store. If that works, they get logged in. But if it doesn't work, the plugin tries a
bunch of different password methods, including VBulletin 4 and VBulletin 5-style passwords. If the
password works for VBulletin 5, then the plugin uses the plaintext password to set their Discourse
password using the Discourse native method.

## nginx config

In my `app.yml` a rewrite line for the nginx config can help make old URLs keep working. VBulletin 5
handles links like `https://www.example.com/forum/1234-example/page2`. It jumps to the second page
of results for that page. These do not work with Discourse.

The migration process **will** build a redirect for `https://www.example.com/forum/1234-example`
to its new Discourse URL. So this nginx rewrite rule strips the `/pageN`
off the request URL so the redirect permalink will match and redirect to the right URL.

```yaml
run:
  - exec: echo "Beginning of custom commands"
  - file:
      path: /etc/nginx/conf.d/example-forum.conf
      contents: |
        rewrite ^(.*)/page\d+ $1 permanent;
```

# Get MariaDB Going

There are two ways to do this. One is to make a copy of your VBulletin database on your discourse
server, and have the Discourse server read that copy. The other option is to connect live to your
real VBulletin forum database. The advantage of copying is that you don't add any extra load to your
VBulletin system and you don't have to make any network connections between the two. The advantage
of connecting live is that you don't have to dump, copy, restore. This can take a lot of time for
large VBulletins.

The first instructions install MariaDB in the container and restore a SQL dump into it.. If you are
going to have your Discourse container connect directly to your VBulletin MariaDB, skip this and
jump to the section "Get mysql support in rails".

### NOTE

These changes that install MariaDB and support for it, will be lost **every time** you do a
`launcher rebuild app` to rebuild your container. That's a step that you do a lot when you're first
installing Discourse (e.g., to install plugins). Ultimately, this is good: when you're finally fully
migrated and you don't *need* the MariaDB in your container any more, it won't be there any more.
But during the migration setup and practice, it's a pain if you clobber it by rebuilding the
container.

Also: MariaDB will not start in the container automatically. Each time you restart your container,
or reboot your host, you will have to enter the container and run `service start mariadb`. There's
no need to always have MariaDB running. Once you're done with your migration, throw it away.

## Install MariaDB in the container

Everyone does this.

```sh
cd /var/discourse
sudo ./launcher enter app
apt update
apt install -y libmariadb-dev mariadb-server vim
```

### Install a copy of the database in the container

If you're installing a copy of the database in your container, do these stesp. If not, skip to "Get
MySQL support in rails."

These commands are still inside the container. If your original VBulletin database is not named
vbforum, change that below.

```sh
service mariadb start

mysql -u root -p -e 'CREATE DATABASE vbforum;' # root has no password, just hit enter
mysql -u root -p -e 'CREATE TABLE customprofilepic (userid INT(11), customprofileid INT(11), thumbnail VARCHAR(255));' vbforum
mysql -u root -p -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'password123';"
```

### Optimize MariaDB for import/export

Edit `/etc/mysql/mariadb.conf.d/50-server.cnf` and insert these lines in the `[mysqld]` section.
Note that I had 16G of RAM on my server, so these are pretty generous. Use smaller values if you
have less RAM.

```
innodb_doublewrite = 0
innodb_flush_log_at_trx_commit = 0
sync_binlog = 0
innodb_buffer_pool_size = 4G
innodb_log_file_size = 512M
innodb_autoinc_lock_mode=2
```

### Import VBulletin Data

If you're running MariaDB in your container, you need to load in a backup of your forum. One way to
pass data in and out is to use `/var/discourse/shared/standalone/uploads` as a bit of working
storage. You can copy data like SQL backups, attachments and avatars into there from outside the
container and various other data like. Inside the container you'll find the data at
`/shared/uploads`.

Assuming your SQL dump of your `vbforum` database is in `vbforum-dump.sql`, you want to copy that to
`/var/discourse/shared/standalone/uploads`. Then you can reference it from your container as
`/shared/uploads/vbforum-dump.sql`.

Typically, you import like this:

```sh
time mysql -u root -p vbforum < /shared/uploads/vbforum-dump.sql
```


## Get MySQL support in rails

Regardless of where your MariaDB is, you need to do these steps. Still inside the app container:

```sh
echo "gem 'mysql2', require: false
gem 'php_serialize', require: false
" | tee -a /var/www/discourse/Gemfile
su discourse -c 'BUNDLE_FROZEN="false" bundle install --no-deployment --without test --without development --path vendor/bundle'
```

## (Optional) Configure postgres for import

You can turn off some postgres safety features while doing the import to gain a small performance boost. If you do this,
be sure to **undo them when you go live**.

```
fsync = off
synchronous_commit = off
full_page_writes = off
autovacuum = off
```

After doing this, restart postgres by running `pg_ctlcluster 15 main reload` in the container.

# Do the Migration

Assuming everything went well, this is the moment of truth. Set up your environment variables for
your import. If you made a copy of your MariaDB in your container, you'll use `DB_HOST="localhost"`.
If you are connecting to your live VBulletin MySQL server somewhere else, you'll need the `DB_`
variables to connect. For example:

```sh
export URL_PREFIX="forum/"
export DB_PREFIX=""
export DB_HOST="192.168.10.4"
export DB_NAME="myforum"
export DB_PASS="password123"
export DB_USER="root"
export ATTACH_DIR="/shared/uploads/attachments"
export AVATAR_DIR="/shared/uploads/avatars"
```

When you're ready, these 3 commands do the migration.

1. `time su discourse -c 'bundle exec ruby script/import_scripts/vbulletin5.rb'`
2. `time su discourse -c 'bundle exec ruby script/import_scripts/import_vb5_pm.rb'`
3. `time su discourse -c 'bundle exec ruby script/import_scripts/import_vb5_avatars.rb'`

The first command will take a **long** time. It processes every single post individually. There's a
ton of processing (something like 20 regular expression evaluations across the raw text for *every
post*.) The fastest I ever saw was about 1100 items/min. 1.7M items / 1100 / 60 = 25.75 hours.

The second command handles PMs specially. They are are essentially posts. But there's a bunch of
specialised handling in there to see if users still exist, whether any participants still have a PM
undeleted, etc.

# Post Migration Cleanup

1. Run `su discourse -c psql` and then in Postgres, run `vacuum analyze;` to clean up disk space.
   You just do this once because auto vacuum was something we disabled for optimization. When you
   undo the optimizations, it will start auto-vacuuming again.
2. If you modified `postgresql.conf`, take out the optimizations and restart your database again.
3. Login on your Discourse and check things out.

# Credits

These are some sources that were used to figure out how to migrate.
* First and foremost this is thanks to folks like [Jay Pfaffman](https://github.com/pfaffman) and [Sam Saffron](https://github.com/SamSaffron) who authored [the original vbulletin4 migration script](https://github.com/discourse/discourse/blob/main/script/import_scripts/vbulletin5.rb) and maintained it over the years.
* [The Discourse Meta](https://meta.discourse.org/): the source of support and ideas and information.
  * [A post on migrating VB5 in 2022](https://meta.discourse.org/t/migrating-vbulletin-5-database-import-script-errors/249495)
  * [Migrating from VB4](https://meta.discourse.org/t/migrate-a-vbulletin-4-forum-to-discourse/54881)
* Mike Polinowski's blog [Migrating from vBulletin 5 to Discourse on CentOS 8](https://mpolinowski.github.io/docs/DevOps/Provisioning/2019-06-16--migrating-from-vbulletin-to-discourse-on-centos8/2019-06-16/)
