<a href="http://www.discourse.org/">![Logo](images/discourse.png)</a>

Discourse is the 100% open source, next-generation discussion platform built for the next decade of the Internet.

Whenever you need ...

- a mailing list
- a forum to discuss something
- a chat room where you can type paragraphs

... consider Discourse.

To learn more about the philosophy and goals of the project, [visit discourse.org](http://www.discourse.org).

## Getting Started

1. If you're **brand new to Ruby and Rails**, please see [**Discourse as Your First Rails App**](http://blog.discourse.org/2013/04/discourse-as-your-first-rails-app/) or our [**Discourse Vagrant Developer Guide**](https://github.com/discourse/discourse/blob/master/docs/VAGRANT.md), which includes instructions to get up and running in a development environment using a virtual machine. This beginner's guide is also adequate for developers ready to sink their teeth quickly; it's the easiest way to hack on Discourse!

2. Once you have Discourse up and running, be sure to load [the appropriate seed data](pg_dumps) on your forum, either the **developer** seed data, which is the same data you'll see on [try.discourse.org](http://try.discourse.org), or the **production** seed data which includes the [Discourse Admin Quick Start Guide](https://github.com/discourse/discourse/wiki/The-Discourse-Admin-Quick-Start-Guide) and meta guidance.

3. If you're familiar with how Rails works and are comfortable setting up your own environment, use our [**Discourse Advanced Developer Guide**](docs/DEVELOPER-ADVANCED.md).

Before you get started, ensure you have the following minimum versions: [Ruby 1.9.3+](http://www.ruby-lang.org/en/downloads/), [PostgreSQL 9.1+](http://www.postgresql.org/download/), [Redis 2.6+](http://redis.io/download). And if you're having trouble, please see our [**TROUBLESHOOTING GUIDE**](docs/TROUBLESHOOTING.md) first!

## Setting up a Discourse Forum

If you're not here to hack on the open source code, but rather looking to set up a Discourse forum in a production environment, see our [**Discourse Install Guide**](/docs/INSTALL-ubuntu.md). Be warned, however, that Discourse is still very much beta, and you will probably need a background as a developer or system administrator to set it up successfully.

## Vision

We think of Discourse as a **Civilized Discourse Construction Kit**, an open-source discussion platform that acts as a free, flexible, fundamental building block for online communities of any size, tiny to huge.

Discourse is: 

- A **flattened, endlessly scrolling discussion**, which avoids the awkwardness of traditionally threaded and paginated discussion, while still allowing replies to be expanded in place for context.

- A **user trust system** that grants users rights to assist in moderating the forum as they participate in good faith over time. The goal is for the forum to be nearly self-moderating in the absence of any formal moderators, although excellent moderators do accelerate the process greatly.

- An **advanced JavaScript app** which runs in modern browsers and works identically on desktop and tablet, without the need for a native app.

- A **contemporary, robust technology stack**, free of legacy PHP and MySQL constraints.

Our goal is to **foster an active community of contributors**, all of whom commit to free, simple, pleasant to use online discussion software that can thrive in an Internet age dominated by micro-blogging and diminishing attention spans. Internet discussion belongs to everyone, not just huge corporate websites.

Discourse is built for the *next* 10 years of the Internet, so our requirements are high:

1. Modern browsers on the desktop:
  - Internet Explorer 9.0 (may not be fully functional), 10.0+
  - Firefox 16+
  - Google Chrome 23+
  - Safari 5+
2. The latest generation of tablets, 7" or larger:
  - iPad 2+
  - Android 4.1+
  - Windows 8
3. Modern small screen mobile/smartphones *as soon as possible*:
  - Windows Phone 8
  - iOS 6+
  - Android 4.0+

## Built With

Discourse is built from the following open source components:

- [Ruby on Rails](https://github.com/rails/rails) - Our back end API is a Rails app. It responds to requests RESTfully and responds in JSON.
- [Ember.js](https://github.com/emberjs/ember.js) - Our front end is an Ember.js app that communicates with the Rails API.
- [PostgreSQL](http://www.postgresql.org/) - Our main data store is in Postgres.
- [Redis](http://redis.io/) - We use Redis for our job queue, rate limiting, as a cache and for transient data.

Plus *lots* of Ruby Gems, a complete list of which is at [**SOFTWARE.MD**](docs/SOFTWARE.md).

## Contributing

[![Build Status](https://travis-ci.org/discourse/discourse.png)](https://travis-ci.org/discourse/discourse)
[![Code Climate](https://codeclimate.com/github/discourse/discourse.png)](https://codeclimate.com/github/discourse/discourse)

Discourse is **100% free** and **open-source**. We encourage and support an active, healthy community that
accepts contributions from the public. We'd like you to be a part of that community.

Before contributing to Discourse, please:

1. Review the [**VISION**](#vision) statement, to confirm that you understand the focus of the project,
2. Read and sign the [**Electronic Discourse Forums Contribution License Agreement**](http://discourse.org/cla), to confirm you've read and acknowledged the legal aspects of your contributions, and
3. Dig into [**CONTRIBUTING.MD**](CONTRIBUTING.md), which houses all of the necessary info to:
   - submit bugs,
   - request new features, and
   - step you through the entire process of preparing your code for a Pull Request.
4. Not sure what to work on? [**We've got some ideas!**](http://meta.discourse.org/t/so-you-want-to-help-out-with-discourse/3823)

We look forward to seeing your cool stuff!

## Having Problems getting set up?

Before contacting us for help, please review our [Troubleshooting Guide](docs/TROUBLESHOOTING.md).

## The Discourse Team

The original Discourse code contributors can be found in [**AUTHORS.MD**](docs/AUTHORS.md). For a complete list of the many individuals that contributed to the design and implementation of Discourse, please refer to [the official Discourse blog](http://blog.discourse.org/2013/02/the-discourse-team/) and [GitHub's list of contributors](https://github.com/discourse/discourse/contributors).


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

Discourse logo and “Discourse Forum” ®, Civilized Discourse Construction Kit, Inc.

## Dedication

Discourse is built with [love, Internet style.](http://www.youtube.com/watch?v=Xe1TZaElTAs)
