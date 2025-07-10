## discourse-oauth2-basic

This plugin allows you to use a basic OAuth2 provider as authentication for
Discourse. It should work with many providers, with the caveat that they
must provide a JSON endpoint for retrieving information about the user
you are logging in.

This is mainly useful for people who are using login providers that aren't
very popular. If you want to use Google, Facebook or Twitter, those are
included out of the box and you don't need this plugin. You can also
look for other login providers in our [Github Repo](https://github.com/discourse).

## Usage

## Part 1: Basic Configuration

First, set up your Discourse application remotely on your OAuth2 provider.
It will require a **Redirect URI** which should be:

`http://DISCOURSE_HOST/auth/oauth2_basic/callback`

Replace `DISCOURSE_HOST` with the appropriate value, and make sure you are
using `https` if enabled. The OAuth2 provider should supply you with a
client ID and secret, as well as a couple of URLs.

Visit your **Admin** > **Settings** > **OAuth2 Login** and fill in the basic
configuration for the OAuth2 provider:

- `oauth2_enabled` - check this off to enable the feature

- `oauth2_client_id` - the client ID from your provider

- `oauth2_client_secret` - the client secret from your provider

- `oauth2_authorize_url` - your provider's authorization URL

- `oauth2_token_url` - your provider's token URL.

If you can't figure out the values for the above settings, check the
developer documentation from your provider or contact their customer
support.

## Part 2: Configuring the JSON User Endpoint

Discourse is now capable of receiving an authorization token from your
OAuth2 provider. Unfortunately, Discourse requires more information to
be able to complete the authentication.

We require an API endpoint that can be contacted to retrieve information
about the user based on the token.

For example, the OAuth2 provider [SoundCloud provides such a URL](https://developers.soundcloud.com/docs/api/reference#me).
If you have an OAuth2 token for SoundCloud, you can make a GET request
to `https://api.soundcloud.com/me?oauth_token=A_VALID_TOKEN` and
will get back a JSON object containing information on the user.

To configure this on Discourse, we need to set the value of the
`oauth2_user_json_url` setting. In this case, we'll input the value of:

```
https://api.soundcloud.com/me?oauth_token=:token
```

The part with `:token` tells Discourse that it needs to replace that value
with the authorization token it received when the authentication completed.
Discourse will also add the `Authorization: Bearer` HTTP header with the
token in case your API uses that instead.

There is one last step to complete. We need to tell Discourse what
attributes are available in the JSON it received. Here's a sample
response from SoundCloud:

```json
{
  "id": 3207,
  "permalink": "jwagener",
  "username": "Johannes Wagener",
  "uri": "https://api.soundcloud.com/users/3207",
  "permalink_url": "http://soundcloud.com/jwagener",
  "avatar_url": "http://i1.sndcdn.com/avatars-000001552142-pbw8yd-large.jpg?142a848",
  "country": "Germany",
  "full_name": "Johannes Wagener",
  "city": "Berlin"
}
```

The `oauth2_json_user_id_path`, `oauth2_json_username_path`, `oauth2_json_name_path` and
`oauth2_json_email_path` variables should be set to point to the appropriate attributes
in the JSON.

The only mandatory attribute is _id_ - we need that so when the user logs on in the future
that we can pull up the correct account. The others are great if available -- they will
make the signup process faster for the user as they will be pre-populated in the form.

Here's how I configured the JSON path settings:

```
  oauth2_json_user_id_path: 'id'
  oauth2_json_username_path: 'permalink'
  oauth2_json_name_path: 'full_name'
```

I used `permalink` because it seems more similar to what Discourse expects for a username
than the username in their JSON. Notice I omitted the email path: SoundCloud do not
provide an email so the user will have to provide and verify this when they sign up
the first time on Discourse.

If the properties you want from your JSON object are nested, you can use periods.
So for example if the API returned a different structure like this:

```json
{
  "user": {
    "id": 1234,
    "email": {
      "address": "test@example.com"
    }
  }
}
```

You could use `user.id` for the `oauth2_json_user_id_path` and `user.email.address` for `oauth2_json_email_path`.

## Part 3: Test it with Google OAuth 2.0 Server

To test this plugin in your local dev environment you can use Google OAuth 2.0 Server. Follow [this guide](https://support.google.com/cloud/answer/6158849?hl=en) to create new OAuth client id & secret.

- While creating it choose "Web application" as "Application type".
- Add `http://localhost:3000` in "Authorized JavaScript origins" and `http://localhost:3000/auth/oauth2_basic/callback` in "Authorized redirect URIs" fields.
- Then add following site settings in your admin panel.

```json
{
  "oauth2_enabled": true,
  "oauth2_client_id": "YOUR_PROJECT_CLIENT_ID",
  "oauth2_client_secret": "YOUR_PROJECT_CLIENT_SECRET",
  "oauth2_authorize_url": "https://accounts.google.com/o/oauth2/auth",
  "oauth2_token_url": "https://www.googleapis.com/oauth2/v3/token",
  "oauth2_user_json_url": "https://www.googleapis.com/userinfo/v2/me",
  "oauth2_json_user_id_path": "id",
  "oauth2_json_user_name_path": "name",
  "oauth2_json_user_email_path": "email",
  "oauth2_json_user_avatar_path": "picture",
  "oauth2_email_verified": true,
  "oauth2_scope": "https://www.googleapis.com/auth/userinfo.email"
}
```

That's it! You can check it now in your browser.

Good luck setting up custom OAuth2 on your Discourse!

### Issues

Please use [this topic on meta](https://meta.discourse.org/t/oauth2-basic-support/33879) to discuss
issues with the plugin, including bugs and feature requests.

### How to run tests

Make sure the plugin has been installed, then from the discourse directory run:

```
LOAD_PLUGINS=1 bundle exec rspec plugins/discourse-oauth2-basic/spec/plugin_spec.rb
```

### License

MIT
