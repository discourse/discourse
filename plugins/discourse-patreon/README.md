# Discourse Patreon

Enable syncronization between Discourse Groups and Patreon rewards, and enable Patreon Social Login,

<img src="public/images/patreon-wordmark-navy.png?raw=true" width="292" height="104">

## Installation

Proceed with a normal [installation of a plugin](https://meta.discourse.org/t/install-a-plugin/19157?u=falco).

## After Installation

You need to fill the following fields on Settings -> Plugins:

- Client ID
- Client Secret
- Creator's Access Token
- Creator's Refesh Token

To get those values you must have a [Creator account first](https://www.patreon.com/become-a-patreon-creator).

Then go to [Clients & API Keys](https://www.patreon.com/platform/documentation/clients) and fill the necessary info.

> The Redirect URIs must be `http://<DISCOURSE BASE URL>/auth/patreon/callback`, like https://meta.discourse.org/auth/patreon/callback for example.

Then you use the generated tokens to configure the plugin.

## Webhooks

You should create [Patreon Webhooks](https://www.patreon.com/platform/documentation/webhooks) so every new pledge get's synced to Discourse ASAP.

> To get it working, create a new Webhook for each trigger type and point then to `https://<DISCOURSE BASE URL>/patreon/webhook`, like https://meta.discourse.org/patreon/webhook for example.

## Group Sync

If you want to give your patrons a special treatment on your board, you can create rules between Discourse Groups and Patreon reward tiers.

This can pave the way to grant category access, titles and custom css to please your patrons!

## Social Login

This plugin will also enable a Social Login with Patreon, making it easier for your patron to sign up on Discourse.

## About

This is a work in progress! Feel free to use and ask questions here, or on [Meta](https://meta.discourse.org/t/discourse-patreon-login/44366?u=falco).

## TODO

- Button to invite patrons who aren't on Discourse yet.
