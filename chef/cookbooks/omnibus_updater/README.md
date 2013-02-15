OmnibusUpdater
==============

Update your omnibus! This cookbook can install the omnibus
Chef package into your system if you are currently running
via gem install, and it can keep your omnibus install up
to date.

Usage
=====

Add the recipe to your run list and specify what version should
be installed on the node:

`knife node run_list add recipe[omnibus_updater]`

In your role you'll likely want to set the version (it defaults
to the 0.10.10 version of Chef):

```
override_attributes(
  :omnibus_updater => {
    :version => '10.16.2'
  }
)
```

It can also uninstall Chef from the system Ruby installation
if you tell it to:

```
override_attributes(
  :omnibus_updater => {
    :remove_chef_system_gem => true
  }
)
```
---

If you are using a Chef version earlier than 10.12.0 you may want
to take a look at the chef_gem cookbook to ensure gems are going
where expected.

---

The default recipe will install the omnibus package based
on system information but you can override that by using
the `install_via` attribute which accepts: deb, rpm or script.

Features
========

Auto version expansion
----------------------

Versions for the omnibus installer are defined as: x.y.z-n If the `:version` attribute only provides
x.y.z the `n` value will be automatically filled in with the latest available version.

Auto version searching
----------------------

Using the `:version_search` attribute, the latest stable version of the omnibus installer will
be installed automatically as they become available.

Release clients
---------------

Release clients can be installed via the auto-installation using `:allow_release_clients` attribute.

Disable
-------

If you want to disable the updater you can set the `disabled`
attribute to true. This might be useful if the cookbook is added
to a role but should then be skipped for example on a Chef server.

Infos
=====

* Repo: https://github.com/hw-cookbooks/omnibus_updater
* IRC: Freenode @ #heavywater

