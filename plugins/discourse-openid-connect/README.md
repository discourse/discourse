# discourse-openid-connect

A plugin to integrate Discourse with an openid-connect login provider

For information and discussion, see https://meta.discourse.org/t/openid-connect-authentication-plugin/103632

## Email claim

The `openid_connect_email_claim` setting selects the top-level claim used for the
user's email address. It defaults to `email`. For providers that return a verified
address under another claim, such as `mail`, set it to that claim name.

The claim is read from UserInfo when a UserInfo endpoint is available, otherwise
from the ID token. There is no fallback to another claim or response if it is
missing. The `openid_connect_claims` setting requests claims from the provider;
it does not rename returned claims.

The email claim must contain a single string. Arrays, objects, booleans, and
numbers are treated as a missing email and cannot be used for email matching.

Only use a claim whose address is verified by the provider and is suitable for
linking to existing Discourse accounts. Existing `email_verified` handling still
applies: an explicit false value prevents email matching, while an absent value
is treated as verified. Automatic email matching also requires
`openid_connect_match_by_email` to be enabled.
