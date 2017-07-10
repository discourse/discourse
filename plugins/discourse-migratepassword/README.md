discourse-migratepassword
=========================

Support migrated password hashes


Installation
============

* Run `bundle exec rake plugin:install repo=http://github.com/discoursehosting/discourse-migratepassword` in your discourse directory
* Restart Discourse

Usage
=====

* Store your alternative password hashes in a custom field named `import_pass`
```
user = User.find_by(username: 'user')
user.custom_fields['import_pass'] = '5f4dcc3b5aa765d61d8327deb882cf99'
user.save
```
  
License
=======

GPL v2

