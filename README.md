<a href="https://www.discourse.org/"><img src=
"https://user-images.githubusercontent.com/1681963/52239617-e2683480-289c-11e9-922b-5da55472e5b4.png"
 width="300px"></a>



Discourse is the 100% open source discussion platform built for the next decade of the Internet. Use it as a:

- mailing list
- discussion forum
- long-form chat room

To learn more about the philosophy and goals of the project, [visit **discourse.org**](https://www.discourse.org).

## Screenshots


<a href="https://bbs.boingboing.net"><img alt="Boing Boing" src="https://user-images.githubusercontent.com/1681963/52239245-04ad8280-289c-11e9-9c88-8c173d4a0422.png" width="720px"></a>
<a href="https://twittercommunity.com/"><img src="https://user-images.githubusercontent.com/1681963/52239250-04ad8280-289c-11e9-9e42-574f6eaab9d7.png" width="720px"></a>
<a href="https://discuss.howtogeek.com"><img src="https://user-images.githubusercontent.com/1681963/52239247-04ad8280-289c-11e9-9706-fd66bc0749dc.png" width="720px"></a>
<a href="https://talk.turtlerockstudios.com/"><img src="https://user-images.githubusercontent.com/1681963/52239249-04ad8280-289c-11e9-9155-f0ccc5decc50.png" width="720px"></a>

<img src="https://user-images.githubusercontent.com/1681963/52239118-b304f800-289b-11e9-9904-16450680d9ec.jpg" alt="Mobile" width="414">

Browse [lots more notable Discourse instances](https://www.discourse.org/customers).

## Development

To get your environment setup, follow the community setup guide for your operating system.

1. If you're on macOS, try the [macOS development guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-macos-for-development/15772).
1. If you're on Ubuntu, try the [Ubuntu development guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-ubuntu-for-development/14727).
1. If you're on Windows, try the [Windows 10 development guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-windows-10-for-development/75149).

If you're familiar with how Rails works and are comfortable setting up your own environment, you can also try out the [**Discourse Advanced Developer Guide**](docs/DEVELOPER-ADVANCED.md), which is aimed primarily at Ubuntu and macOS environments.

Before you get started, ensure you have the following minimum versions: [Ruby 2.5+](https://www.ruby-lang.org/en/downloads/), [PostgreSQL 10+](https://www.postgresql.org/download/), [Redis 2.6+](https://redis.io/download). If you're having trouble, please see our [**TROUBLESHOOTING GUIDE**](docs/TROUBLESHOOTING.md) first!

## Setting up Discourse

If you want to set up a Discourse forum for production use, see our [**Discourse Install Guide**](docs/INSTALL.md).

If you're looking for business class hosting, see [discourse.org/buy](https://www.discourse.org/buy/).

## Requirements

Discourse is built for the *next* 10 years of the Internet, so our requirements are high.

Discourse supports the **latest, stable releases** of all major browsers and platforms:

| Browsers              | Tablets      | Phones       |
| --------------------- | ------------ | ------------ |
| Apple Safari          | iPadOS       | iOS          |
| Google Chrome         | Android      | Android      |
| Microsoft Edge        |              |              |
| Mozilla Firefox       |              |              |

## Built With

- [Ruby on Rails](https://github.com/rails/rails) &mdash; Our back end API is a Rails app. It responds to requests RESTfully in JSON.
- [Ember.js](https://github.com/emberjs/ember.js) &mdash; Our front end is an Ember.js app that communicates with the Rails API.
- [PostgreSQL](https://www.postgresql.org/) &mdash; Our main data store is in Postgres.
- [Redis](https://redis.io/) &mdash; We use Redis as a cache and for transient data.

Plus *lots* of Ruby Gems, a complete list of which is at [/master/Gemfile](https://github.com/discourse/discourse/blob/master/Gemfile).

## Contributing

[![Build Status](https://api.travis-ci.org/discourse/discourse.svg?branch=master)](https://travis-ci.org/discourse/discourse)

Discourse is **100% free** and **open source**. We encourage and support an active, healthy community that
accepts contributions from the public &ndash; including you!

Before contributing to Discourse:

1. Please read the complete mission statements on [**discourse.org**](https://www.discourse.org). Yes we actually believe this stuff; you should too.
2. Read and sign the [**Electronic Discourse Forums Contribution License Agreement**](https://www.discourse.org/cla).
3. Dig into [**CONTRIBUTING.MD**](CONTRIBUTING.md), which covers submitting bugs, requesting new features, preparing your code for a pull request, etc.
4. Always strive to collaborate [with mutual respect](https://github.com/discourse/discourse/blob/master/docs/code-of-conduct.md).
5. Not sure what to work on? [**We've got some ideas.**](https://meta.discourse.org/t/so-you-want-to-help-out-with-discourse/3823)


We look forward to seeing your pull requests!

## Security

We take security very seriously at Discourse; all our code is 100% open source and peer reviewed. Please read [our security guide](https://github.com/discourse/discourse/blob/master/docs/SECURITY.md) for an overview of security measures in Discourse, or if you wish to report a security issue.

## The Discourse Team

The original Discourse code contributors can be found in [**AUTHORS.MD**](docs/AUTHORS.md). For a complete list of the many individuals that contributed to the design and implementation of Discourse, please refer to [the official Discourse blog](https://blog.discourse.org/2013/02/the-discourse-team/) and [GitHub's list of contributors](https://github.com/discourse/discourse/contributors).


## Copyright / License

Copyright 2014 - 2019 Civilized Discourse Construction Kit, Inc.

Licensed under the GNU General Public License Version 2.0 (or later);
you may not use this work except in compliance with the License.
You may obtain a copy of the License in the LICENSE file, or at:

   https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Discourse logo and “Discourse Forum” ®, Civilized Discourse Construction Kit, Inc.

## Dedication

Discourse is built with [love, Internet style.](https://www.youtube.com/watch?v=Xe1TZaElTAs)
