<a href="http://www.discourse.org/">![Logo](https://raw.github.com/discourse/discourse/master/images/discourse.png)</a>

Discourse is the 100% open source, next-generation discussion platform built for the next 10 years of the Internet.

Whenever you need ...

* a mailing list
* a forum to discuss something
* a chat room where you can type paragraphs

... consider Discourse.


## Getting Started

If you're interested in helping us develop Discourse, please start with our **[Discourse Developer Install Guide](https://github.com/discourse/discourse/blob/master/DEVELOPMENT.md)**, which includes instructions to get up and running in a development environment.

### Requirements

* PostgreSQL 9.1+
* Redis 2+

### The quick and easy setup

```
git clone git@github.com:discourse/discourse.git
cd discourse
bundle install
rake db:create
rake db:migrate
rake db:seed_fu
redis-cli flushall
thin start
```

## Vision

This is the **Civilized Discourse Construction Kit**, a fully open-source package of forum software that is free to use and contribute to. Discourse embraces the changes that are necessary to evolve forum software, namely:

* A **flattened discussion**, which avoids the pains of threaded forums, and delivers a more robust, intuitive interface to join a conversation at any point.
* A **self-learning system**, capable of examining the behavior of the community, and adapting to budding moderators and forum trolls alike.
* A **seamless web-only** interface that delivers usability on both the desktop and the tablet, without the need for a native app.
* A **contemporary, robust technology stack**, so that both users and administrators alike have another choice BESIDES php.

The Discourse team wishes to **foster an active community of contributors**, all of whom commit to delivering this continued vision, and ensure that online discussions can grow and thrive in an Internet age dominated by micro-blogging and diminishing attention spans.

This vision translates to the following functional commitments:

1. Support all contemporary browsers on the desktop:
  * Internet Explorer 9.0, 10.0+
  * Firefox 16+
  * Google Chrome *infinite*
   
2. Supporting the latest generation of tablets:  
  * iPad 2+
  * Android 4.1+ on 7" and 10"
  * Windows 8

3. Deliver support for mobile/smartphones *as soon as possible*:
  * Windows Phone 8
  * iPhone 4+
  * Android 4.0+

## Contributing

[![Build Status](https://travis-ci.org/discourse/discourse.png)](https://travis-ci.org/discourse/discourse)

Discourse is **100% free** and **open-source**. We encourage and support an active, healthy community that
accepts contributions from the public, and we'd like you to be a part of that community.

In order to be prepared for contributing to Discourse, please:

1. Review the **VISION** section above, which will help you understand the needs of the team, and the focus of the project,
2. Read & sign the **[Electronic Discourse Forums Contribution License Agreement](https://docs.google.com/a/discourse.org/spreadsheet/viewform?formkey=dGUwejFfbDhDYXR4bVFMRG1TUENqLWc6MQ)**, to confirm you've read and acknowledged the legal aspects of your contributions, and
3. Dig into **[CONTRIBUTING.MD](https://github.com/discourse/discourse/blob/master/CONTRIBUTING.md)**, which houses all of the necessary info to:
   * submit bugs,
   * request new features, and
   * step you through the entire process of preparing your code for a Pull Request.

**We look forward to seeing your cool stuff!**

## Expertise

Discourse implements a variety of open source tech. You may wish to familiarize yourself with the various components that Discourse is built on, in order to be an effective contributor:

### Languages/Frameworks

1. [Ruby on Rails](https://github.com/rails/rails) - Our back end API is a Rails app. It responds to requests RESTfully and responds in JSON.
2. [Ember.js](https://github.com/emberjs/ember.js) - Our front end interface is an Ember.js app that communicates with the Rails API.

### Databases

1. [PostgreSQL](http://www.postgresql.org/) - Our main data store is Postgres.
2. [Redis](http://redis.io/) - We use Redis for our job queue, rate limiting, as a cache and for transient data.

### Ruby Gems

The complete list of Ruby Gems used by Discourse can be found in [SOFTWARE.md](https://github.com/discourse/discourse/blob/master/SOFTWARE.md).

## Versioning

Discourse implements the Semantic Versioning guidelines.

Releases will be numbered with the following format:

`<major>.<minor>.<patch>`

And constructed with the following guidelines:

* Breaking backward compatibility bumps the major (and resets the minor and patch)
* New additions without breaking backward compatibility bumps the minor (and resets the patch)
* Bug fixes and misc changes bumps the patch

For more information on SemVer, please visit http://semver.org/.

## The Discourse Team

The Discourse code contributors can be found in [AUTHORS.MD](https://github.com/discourse/discourse/blob/master/AUTHORS.md). For a complete list of the many individuals that contributed to the design and implementation of Discourse, please refer to the official website.

## Copyright / License

Copyright 2013 Civilized Discourse Construction Kit, Inc.

Licensed under the GNU General Public License Version 2.0 (or later);
you may not use this work except in compliance with the License.
You may obtain a copy of the License in the LICENSE file, or at:

   http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
