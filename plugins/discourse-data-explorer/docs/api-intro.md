This is the documentation for Discourse's JSON:API — currently an experiment scoped to
the Data Explorer plugin. Responses follow the [JSON:API specification](https://jsonapi.org/format/)
with the `application/vnd.api+json` media type.

# Authentication

Create an API key in the admin panel and pass it with every request:

```
Api-Key: 714552c6148e1617aeab526d0606184b94a80ec048fc09894ff1a72b740c5f19
Api-Username: system
```

# Versioning

Every request must carry a pinned API version — a date:

```
Api-Version: 2026-07-08
```

The date snaps down to the nearest version at or before it, and the **resolved** version is
echoed back in the response's `Api-Version` header. The integration ritual: send today's
date once, store the echoed value verbatim, and send it from then on — your responses will
never change shape, no matter what the API ships later.

Plugins that release independently from Discourse have their own timelines. To opt into a
newer version of one, add an override: `Api-Version: 2026-07-08; some-plugin=2026-07-15`.
The echo resolves each date against its own timeline; store it as-is.

# Pagination

Collections use cursor pagination (the JSON:API
[cursor pagination profile](https://jsonapi.org/profiles/ethanresnick/cursor-pagination)):
`page[size]`, `page[after]`, `page[before]`. Follow the `links.prev` / `links.next` URLs —
they are null when there is no page in that direction. There is no offset pagination.

# Errors

Errors are JSON:API error objects. Unknown filters, sorts, includes, or page parameters
are rejected with a `400` naming the offender; validation failures answer `422` with a
JSON Pointer (`source.pointer`) per invalid attribute, expressed in your pinned version's
vocabulary.
