<a href="https://www.discourse.org/">
  <img src="images/discourse-readme-logo.png" width="300px">
</a>

The online home for your community. 

![readme](https://github.com/user-attachments/assets/db764ef2-5cc2-4873-b11d-4a2052e1993d)


> You can self-host Discourse on your own infrastructure. But if you'd rather skip the setup, maintenance, and server management, we offer official Discourse hosting.
>
> 👉 Learn more about [Discourse hosting](https://discourse.org/pricing)

Discourse is a 100% open-source community platform for those who want complete control over how and where their site is run.

Our platform has been battle-tested for over a decade and continues to evolve to meet users’ needs for a powerful community platform. 

**With Discourse, you can:**

* 💬 **Create discussion topics** to foster meaningful conversations.

* ⚡️ **Connect in real-time** with built-in chat.
  
* 🎨 **Customize your experience** with an ever-growing selection of official and community themes.

* 🤖 **Enhance your community** with plugins, from chatbots powered by [Discourse AI](https://meta.discourse.org/t/discourse-ai/259214) to advanced tools like SQL analysis with the [Data Explorer](https://meta.discourse.org/t/discourse-data-explorer/32566) plugin.

To learn more, visit [discourse.org](https://www.discourse.org/) and join our support community at [meta.discourse.org](https://meta.discourse.org/).


Here are just a few of the incredible communities using Discourse: 

![discourse-communities](https://github.com/user-attachments/assets/a79b5d56-7748-4f6d-8a2d-daa950366fcc)

👉 [Discover more communities using Discourse](https://discover.discourse.org/)


## Development

To get your environment set up, follow one of the setup guides:

- [Docker / Dev Container](https://meta.discourse.org/t/336366)
- [macOS](https://meta.discourse.org/t/15772)
- [Ubuntu/Debian](https://meta.discourse.org/t/14727)
- [Windows](https://meta.discourse.org/t/75149)

Before you get started, ensure you have the following minimum versions: [Ruby 3.3+](https://www.ruby-lang.org/en/downloads/), [PostgreSQL 13](https://www.postgresql.org/download/), [Redis 7](https://redis.io/download).

For more information, check out [the Developer Documentation](https://meta.discourse.org/c/documentation/developer-guides/56).

## Setting up Discourse

If you want to set up a Discourse forum for production use, see our [**Discourse Install Guide**](docs/INSTALL.md).

If you're looking for official hosting, see [discourse.org/pricing](https://www.discourse.org/pricing/).

## Requirements

Discourse supports the **latest, stable releases** of all major browsers and platforms:

| Browsers              | Tablets      | Phones       |
| --------------------- | ------------ | ------------ |
| Apple Safari          | iPadOS       | iOS          |
| Google Chrome         | Android      | Android      |
| Microsoft Edge        |              |              |
| Mozilla Firefox       |              |              |

Additionally, we aim to support Safari on iOS 15.7+.

## Built With

- [Ruby on Rails](https://github.com/rails/rails) &mdash; Our back end API is a Rails app. It responds to requests RESTfully in JSON.
- [Ember.js](https://github.com/emberjs/ember.js) &mdash; Our front end is an Ember.js app that communicates with the Rails API.
- [PostgreSQL](https://www.postgresql.org/) &mdash; Our main data store is in Postgres.
- [Redis](https://redis.io/) &mdash; We use Redis as a cache and for transient data.
- [BrowserStack](https://www.browserstack.com/) &mdash; We use BrowserStack to test on real devices and browsers.

Plus *lots* of Ruby Gems, a complete list of which is at [/main/Gemfile](https://github.com/discourse/discourse/blob/main/Gemfile).

## Contributing

[![Build Status](https://github.com/discourse/discourse/actions/workflows/tests.yml/badge.svg)](https://github.com/discourse/discourse/actions)

Discourse is **100% free** and **open source**. We encourage and support an active, healthy community that
accepts contributions from the public &ndash; including you!

Before contributing to Discourse:

1. Please read the complete mission statements on [**discourse.org**](https://www.discourse.org). Yes we actually believe this stuff; you should too.
2. Read and sign the [**Electronic Discourse Forums Contribution License Agreement**](https://www.discourse.org/cla).
3. Dig into [**CONTRIBUTING.MD**](CONTRIBUTING.md), which covers submitting bugs, requesting new features, preparing your code for a pull request, etc.
4. Always strive to collaborate [with mutual respect](https://github.com/discourse/discourse/blob/main/docs/code-of-conduct.md).
5. Not sure what to work on? [**We've got some ideas.**](https://meta.discourse.org/t/so-you-want-to-help-out-with-discourse/3823)


We look forward to seeing your pull requests!

## Security

We take security very seriously at Discourse; all our code is 100% open source and peer reviewed. Please read [our security guide](https://github.com/discourse/discourse/blob/main/docs/SECURITY.md) for an overview of security measures in Discourse, or if you wish to report a security issue.

Security fixes are listed in the [release notes](https://meta.discourse.org/tags/c/announcements/67/release-notes) for each version.

## The Discourse Team

The original Discourse code contributors can be found in [**AUTHORS.MD**](docs/AUTHORS.md). For a complete list of the many individuals that contributed to the design and implementation of Discourse, please refer to [the official Discourse blog](https://blog.discourse.org/2013/02/the-discourse-team/) and [GitHub's list of contributors](https://github.com/discourse/discourse/contributors).

## Copyright / License

Copyright 2014 - 2025 Civilized Discourse Construction Kit, Inc.

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

## Accessibility

To guide our ongoing effort to build accessible software we follow the [W3C’s Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/TR/WCAG21/). If you'd like to report an accessibility issue that makes it difficult for you to use Discourse, email accessibility@discourse.org. For more information visit [discourse.org/accessibility](https://discourse.org/accessibility).

## Dedication

Discourse is built with [love, Internet style.](https://www.youtube.com/watch?v=Xe1TZaElTAs)

For over a decade, our [amazing community](https://meta.discourse.org/) has helped shape Discourse into what it is today. Your support, feedback, and contributions have been invaluable in making Discourse a powerful and versatile platform.

We’re deeply grateful for every feature request, bug report, and discussion that has driven Discourse forward. Thank you for being a part of this journey—we couldn’t have done it without you!

