# JSON:API v1.1 — Field Guide

A concrete, example-driven reference for the [JSON:API specification, v1.1](https://jsonapi.org/format/),
including the official **Cursor Pagination profile**. Written for engineers building a JSON:API
server. Every rule states its RFC-2119 force (**MUST** / **MUST NOT** / **SHOULD** / **MAY**),
or is explicitly labeled a *non-normative note*, a *recommendation* (from the non-normative
[Recommendations](https://jsonapi.org/recommendations/) page), or *left to the server*.

All content below was verified against the primary sources listed in the
[Bibliography](#14-bibliography). **Last researched: 2026-07-09.**

---

## Table of contents

1. [TL;DR](#1-tldr)
2. [Media type & content negotiation](#2-media-type--content-negotiation)
3. [Document structure](#3-document-structure)
4. [Fetching resources & relationships](#4-fetching-resources--relationships)
5. [Inclusion of related resources (`include`)](#5-inclusion-of-related-resources-include)
6. [Sparse fieldsets (`fields[TYPE]`)](#6-sparse-fieldsets-fieldstype)
7. [Sorting (`sort`)](#7-sorting-sort)
8. [Pagination — base spec + Cursor Pagination profile](#8-pagination)
9. [Filtering (`filter`)](#9-filtering-filter)
10. [Writes: creating, updating, deleting](#10-writes-creating-updating-deleting)
11. [Errors](#11-errors)
12. [The commonly-misread spots](#12-the-commonly-misread-spots)
13. [JSON:API 1.0 → 1.1 differences](#13-jsonapi-10--11-differences)
14. [Bibliography](#14-bibliography)

---

## 1. TL;DR

JSON:API is a wire-format specification: it defines how clients request resources and how
servers shape request/response documents, so that neither side has to bikeshed document
structure. It exchanges documents using the media type `application/vnd.api+json` and is
versioned additively ("never remove, only add"), so 1.1 is a strict superset of 1.0.

### The 10 rules people most need

1. Every payload is sent with `Content-Type: application/vnd.api+json`. The **only** media type
   parameters allowed are `ext` and `profile` (**MUST NOT** use any other — see [§2](#2-media-type--content-negotiation)).
2. Every document's top level **MUST** contain at least one of `data`, `errors`, `meta` (or an
   extension-defined member) — and `data` and `errors` **MUST NOT** coexist.
3. Every resource object **MUST** carry string `type` and `id` members (exception: a client-side
   *new* resource may omit `id` and **MAY** use `lid` instead). This applies to **request** bodies
   too: `type` is always required.
4. Collections are always JSON arrays (possibly `[]`); single-resource endpoints return one
   resource object or `null`. A collection response is never `null`.
5. Updates use `PATCH`, not `PUT`. Attributes missing from a `PATCH` **MUST** be treated as
   "keep current value", **MUST NOT** be treated as `null`.
6. A request **MUST** completely succeed or fail — no partial writes.
7. Compound documents put related resources in a flat top-level `included` array with **full
   linkage** (every included resource reachable from primary data via relationships), and
   **MUST NOT** contain two resource objects with the same `type`+`id`.
8. The query parameters `include`, `fields[TYPE]`, `sort`, `page[...]`, `filter[...]` are
   reserved by the spec. An unsupported `include`, an unresolvable include path, or an
   unsupported `sort` **MUST** produce `400 Bad Request`.
9. Custom (implementation-specific) query parameters **MUST** have a base name containing at
   least one character outside `a-z` (e.g. a capital letter: `camelCase`). A server that sees a
   query parameter it can't process **MUST** return `400 Bad Request`.
10. Errors are returned as a top-level `errors` **array** of error objects; each error object
    **MUST** contain at least one of the standard members ([§11](#11-errors)).

### The 5 most commonly misread spots (details in [§12](#12-the-commonly-misread-spots))

1. **Sort fields are not required to be attribute names**, and `sort=author.name` dotted paths
   are only a *recommendation in a non-normative note* — not spec grammar.
2. **`filter` semantics are entirely server-defined.** The base spec only reserves the parameter
   family; there is no standard operator syntax.
3. **`fields[TYPE]` values, by contrast, ARE the resource's field names by definition** —
   "fields" is a defined term meaning attributes + relationships.
4. **A custom media type parameter (e.g. `;version=2`) is non-conformant** and triggers
   mandatory `415`/`406` behavior. Only `ext` and `profile` are legal.
5. **`PATCH`, not `PUT`** — and `POST`/`PATCH` request documents are *typed*: the resource
   object in the body **MUST** contain `type` (and `id` for `PATCH`).

---

## 2. Media type & content negotiation

The JSON:API media type is **`application/vnd.api+json`**
([registered with IANA](https://www.iana.org/assignments/media-types/application/vnd.api+json)).

### 2.1 Media type parameters: only `ext` and `profile`

> "The JSON:API media type **MUST NOT** be specified with any media type parameters other
> than `ext` and `profile`."

- `ext` — a space-separated list of **extension** URIs. Extensions add *specification
  semantics* (new members, new processing rules) and require agreement between client and
  server.
- `profile` — a space-separated list of **profile** URIs. Profiles standardize
  *implementation semantics* (things the spec leaves to the server, e.g. pagination
  strategy) and can be safely ignored by a party that doesn't recognize them.
- The values of `ext` and `profile` **MUST** equal a space-separated list of URIs.
  (Non-normative note: HTTP requires quoting such parameter values.)
- Visiting an extension's/profile's URI **SHOULD** return documentation describing its usage.

```http
Content-Type: application/vnd.api+json;ext="https://jsonapi.org/ext/atomic"
Content-Type: application/vnd.api+json;profile="https://jsonapi.org/profiles/ethanresnick/cursor-pagination"
```

Consequence spelled out: **a homegrown parameter like
`application/vnd.api+json;version=2` is non-conformant**, and a conformant server is
*required* to reject it (see the 415/406 rules below). If you need API versioning signals,
use a separate header, the URL, or a profile — not a media type parameter.

### 2.2 Universal responsibilities (clients and servers)

- Clients and servers **MUST** send all JSON:API payloads with the JSON:API media type in the
  `Content-Type` header.
- Clients and servers **MUST** specify the `ext` parameter in `Content-Type` when they have
  applied one or more extensions to the document, and **MUST** specify the `profile`
  parameter when they have applied one or more profiles.

### 2.3 Client responsibilities

- When processing a response, clients **MUST** ignore any parameters other than `ext` and
  `profile` in the server's `Content-Type`.
- A client **MAY** use `ext` in `Accept` to *require* extensions, and **MAY** use `profile`
  in `Accept` to *request* profiles. (Extensions are strict agreement; profiles are
  best-effort — see 2.4.)

### 2.4 Server responsibilities — the 415/406 decision table

| Situation | Required response |
|---|---|
| Request `Content-Type` is the JSON:API media type with any parameter other than `ext`/`profile` | **MUST** `415 Unsupported Media Type` |
| Request `Content-Type` has `ext` containing an unsupported extension URI | **MUST** `415 Unsupported Media Type` |
| `Accept` contains JSON:API media type instances modified by a parameter other than `ext`/`profile` | **MUST** ignore those instances |
| *All* JSON:API instances in `Accept` are modified with a parameter other than `ext`/`profile` | **MUST** `406 Not Acceptable` |
| *Every* JSON:API instance in `Accept` is modified by `ext` and *each* contains at least one unsupported extension URI | **MUST** `406 Not Acceptable` |
| `profile` parameter received | **SHOULD** attempt to apply the requested profile(s); **MUST** ignore any profile it does not recognize |

Non-normative note in the spec: these rules "guarantee strict agreement on extensions between
the client and server, while the application of profiles is left to the discretion of the
server."

- Servers that support `ext` or `profile` **SHOULD** send `Vary: Accept` (on responses with
  *and* without profiles/extensions applied).
- The `jsonapi` object's `ext`/`profile` members ([§3.8](#38-the-jsonapi-object)) **MUST NOT**
  be used for content negotiation: "Content negotiation **MUST** only happen based on media
  type parameters in `Content-Type` header."

Backward-compat note (non-normative): a JSON:API 1.0-only server will respond `415` whenever
`ext` or `profile` is present, since 1.0 forbade all media type parameters.

---

## 3. Document structure

JSON:API documents are JSON (RFC 8259). Unless otherwise noted, objects defined by the spec
(or applied extensions) **MUST NOT** contain additional members, and implementations **MUST**
ignore non-compliant members (this is what makes additive evolution safe).

### 3.1 Top level

A JSON object **MUST** be at the root of every request and response document containing data.

A document **MUST** contain at least one of:

| Member | Meaning |
|---|---|
| `data` | the document's "primary data" |
| `errors` | an array of [error objects](#11-errors) |
| `meta` | a meta object with non-standard meta-information |
| *(extension member)* | a member defined by an applied extension |

- `data` and `errors` **MUST NOT** coexist in the same document.
- A document **MAY** also contain: `jsonapi`, `links`, `included`.
- If a document has no top-level `data` key, `included` **MUST NOT** be present either.

The top-level `links` object **MAY** contain:

- `self` — the link that generated the current response document. If extensions/profiles are
  applied, this **SHOULD** be a link object whose `type` member specifies the full media type
  with parameters. (Non-normative note: `self` must reproduce the client's query parameters
  so the client can refresh the document.)
- `related` — a related resource link, when the primary data represents a relationship.
- `describedby` — a link to a description document (e.g. OpenAPI or JSON Schema). *(New in 1.1.)*
- pagination links (`first`/`last`/`prev`/`next`) for the primary data.

**Primary data MUST be either:**

- for single-resource targets: a single resource object, a single resource identifier object,
  or `null`;
- for collection targets: an array of resource objects, an array of resource identifier
  objects, or an empty array `[]`.

> "A logical collection of resources **MUST** be represented as an array, even if it only
> contains one item or is empty."

### 3.2 Resource objects

```json
{
  "type": "articles",
  "id": "1",
  "attributes": { "title": "Rails is Omakase" },
  "relationships": {
    "author": {
      "links": {
        "self": "/articles/1/relationships/author",
        "related": "/articles/1/author"
      },
      "data": { "type": "people", "id": "9" }
    }
  },
  "links": { "self": "http://example.com/articles/1" },
  "meta": { "revision": 4 }
}
```

- A resource object **MUST** contain `id` and `type`.
  - **Exception:** `id` is not required when the resource object originates at the client and
    represents a new resource to be created. In that case the client **MAY** include a `lid`
    (local ID) to identify the resource by type locally within the document; the `lid` value
    **MUST** be identical for every representation of that resource in the document.
- A resource object **MAY** contain `attributes`, `relationships`, `links`, `meta`.
- The values of `id`, `type`, and `lid` **MUST** be strings.
- Within a given API, each `type` + `id` pair **MUST** identify a single, unique resource.
- `type` values **MUST** adhere to the same constraints as member names ([§3.7](#37-member-names)).
  Non-normative note: the spec is agnostic about singular vs plural `type`; just be consistent.

**Fields.** A resource object's attributes and its relationships are *collectively called its
"fields"*. Fields **MUST** share a common namespace with each other and with `type` and `id` —
i.e. you cannot have an attribute and a relationship with the same name, nor an attribute or
relationship named `type` or `id`.

**Attributes.** The value of `attributes` **MUST** be an object. Attribute values may be any
JSON value, including nested objects/arrays. Keys that reference related resources (e.g.
`author_id`) **SHOULD NOT** appear as attributes — relationships **SHOULD** be used instead.

**Relationships.** The value of `relationships` **MUST** be an object; each member's value
**MUST** be a "relationship object", which **MUST** contain at least one of:

- `links` — containing at least one of:
  - `self`: the *relationship link*, for manipulating the relationship itself (fetching it
    returns the linkage as primary data);
  - `related`: a *related resource link* (fetching it returns the related resource(s) as
    primary data);
  - an extension-defined member;
- `data` — *resource linkage* (see below);
- `meta`;
- an extension-defined member.

A to-many relationship object **MAY** also contain pagination links under `links`; any such
pagination links **MUST** paginate the relationship data (the linkage), not the related
resources.

If present, a related resource link **MUST** reference a valid URL even if the relationship
is currently empty, and **MUST NOT** change because the relationship's content changes.

**Resource linkage** (`data` inside a relationship object) **MUST** be one of:

| Relationship state | Linkage value |
|---|---|
| empty to-one | `null` |
| empty to-many | `[]` |
| non-empty to-one | a single resource identifier object |
| non-empty to-many | an array of resource identifier objects |

Non-normative note: the spec imparts no meaning to the *order* of linkage arrays, though
implementations may.

**Resource-level `links`.** **MAY** contain `self`. A server **MUST** respond to a `GET` of
that URL with the resource as primary data.

### 3.3 Resource identifier objects

An object that identifies an individual resource:

```json
{ "type": "people", "id": "9" }
```

- **MUST** contain `type`; **MUST** contain `id` — except when it represents a new
  client-created resource, in which case a `lid` member **MUST** be included instead.
- **MAY** include `meta`.

### 3.4 Compound documents (`included`)

Servers **MAY** return related resources alongside primary data ("compound documents").

- All included resources **MUST** be represented as an array of resource objects in a
  top-level `included` member.
- **Full linkage:** every included resource **MUST** be identifiable via a chain of
  relationships originating in the document's primary data. The *only* exception is when
  relationship fields that would contain the linkage are excluded by client-requested
  [sparse fieldsets](#6-sparse-fieldsets-fieldstype).
- A compound document **MUST NOT** include more than one resource object for each `type`+`id`
  pair (deduplication — the same person referenced by five comments appears once).
- For client documents: a `lid` alone is sufficient to establish identity/linkage throughout
  the document (non-normative note).

See [§5](#5-inclusion-of-related-resources-include) for a full example.

### 3.5 Meta objects

Wherever the spec says a `meta` member may appear, its value **MUST** be an object; *any*
members **MAY** appear inside it. This is the escape hatch for non-standard information.

### 3.6 Links and link objects

The value of any `links` member **MUST** be an object ("links object"). Each link **MUST** be
represented as one of:

- a string (a URI-reference per RFC 3986 §4.1);
- a link object;
- `null` if the link does not exist.

A **link object** **MUST** contain `href`, and **MAY** contain: `rel` (a valid link relation
type), `describedby`, `title`, `type` (target media type — hint only), `hreflang` (string or
array of language tags — hint only), `meta`.

```json
"links": {
  "self": "http://example.com/articles/1/relationships/comments",
  "related": {
    "href": "http://example.com/articles/1/comments",
    "title": "Comments",
    "describedby": "http://example.com/schemas/article-comments",
    "meta": { "count": 10 }
  }
}
```

A link's relation type **SHOULD** be inferred from its name unless a link object supplies `rel`.

### 3.7 Member names

Implementation- and profile-defined member names **MUST** be treated as case-sensitive and
**MUST**: contain at least one character; contain only allowed characters; start and end with
a "globally allowed character".

- Globally allowed anywhere: `a-z`, `A-Z`, `0-9`, and U+0080+ (non-ASCII; *not recommended*,
  not URL safe).
- Allowed in the middle only: `-`, `_`, and space (space *not recommended*, not URL safe).
- **RECOMMENDED**: use only non-reserved, URL-safe characters (RFC 3986).
- A long list of characters **MUST NOT** be used at all, including: `+ , . [ ] ! " # $ % & ' ( ) * / : ; < = > ? \ ^ ` { | } ~`,
  DEL, C0 controls — and `@` *except* as the first character of an @-Member.

**@-Members** *(new in 1.1)*: member names **MAY** begin with `@`. Such members are pure
implementation semantics and **MUST** be ignored when interpreting the spec's definitions —
e.g. an `@`-member inside `attributes` is *not* an attribute. (Non-normative note: useful for
embedding JSON-LD.)

**Extension members** **MUST** be prefixed with the extension's namespace plus `:`
(e.g. `atomic:operations`); the remainder must follow implementation member-name rules.

The [Recommendations page](https://jsonapi.org/recommendations/) (non-normative) additionally
suggests: camelCase member names, starting/ending `a-z`, ASCII alphanumerics only.

### 3.8 The `jsonapi` object

A document **MAY** include a top-level `jsonapi` member; if present it **MUST** be an object,
which **MAY** contain:

```json
{
  "jsonapi": {
    "version": "1.1",
    "ext": ["https://jsonapi.org/ext/atomic"],
    "profile": ["https://jsonapi.org/profiles/ethanresnick/cursor-pagination"],
    "meta": {}
  }
}
```

If `version` is absent, clients should assume at least 1.0. Reminder: `ext`/`profile` here are
informational; content negotiation **MUST** happen only via `Content-Type` parameters.

---

## 4. Fetching resources & relationships

### 4.1 Endpoints a server must serve

A server **MUST** support fetching resource data for every URL it provides as:

- a `self` link in the top-level `links` object;
- a `self` link in a resource-level `links` object;
- a `related` link in a relationship-level `links` object.

And it **MUST** support fetching relationship data for every relationship URL provided as a
`self` link in a relationship's `links` object.

(The familiar URL shapes — `/articles`, `/articles/1`, `/articles/1/author`,
`/articles/1/relationships/author` — are **recommendations**, not requirements. The FAQ is
explicit: "JSON:API has no requirements about URI structure.")

### 4.2 Fetching resources

```http
GET /articles/1 HTTP/1.1
Accept: application/vnd.api+json
```

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "links": { "self": "http://example.com/articles/1" },
  "data": {
    "type": "articles",
    "id": "1",
    "attributes": { "title": "JSON:API paints my bikeshed!" },
    "relationships": {
      "author": { "links": { "related": "http://example.com/articles/1/author" } }
    }
  }
}
```

- A successful fetch **MUST** return `200 OK`.
- Collection fetch: primary data **MUST** be an array of resource objects or `[]`.
- Individual fetch: primary data **MUST** be a resource object or `null`.
- `null` is *only* appropriate when the URL is one that "might correspond to a single
  resource, but doesn't currently" — the canonical case is a to-one *related resource link*
  whose relationship is empty:

```http
GET /articles/1/author HTTP/1.1
Accept: application/vnd.api+json
```

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "links": { "self": "http://example.com/articles/1/author" },
  "data": null
}
```

- **404**: a server **MUST** respond `404 Not Found` to a fetch of a single resource that
  does not exist — *except* in the 200-with-`null` case above. (So: `GET /articles/999` where
  no such article exists → `404`. `GET /articles/1/author` where article 1 exists but has no
  author → `200` + `data: null`.)
- A server **MAY** respond with other HTTP status codes and **MAY** include error details;
  servers **MUST** prepare (and clients **MUST** interpret) responses per HTTP semantics.

### 4.3 Fetching relationships (linkage endpoints)

```http
GET /articles/1/relationships/tags HTTP/1.1
Accept: application/vnd.api+json
```

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "links": {
    "self": "/articles/1/relationships/tags",
    "related": "/articles/1/tags"
  },
  "data": [
    { "type": "tags", "id": "2" },
    { "type": "tags", "id": "3" }
  ]
}
```

- Success **MUST** be `200 OK`; primary data **MUST** match the resource-linkage rules
  (`null` / `[]` / identifier / identifier array). Empty relationship → `200` with
  `data: null` (to-one) or `data: []` (to-many) — **MUST** be returned, not 404.
- A server **MUST** return `404 Not Found` when the relationship link URL itself does not
  exist (non-normative note: e.g. the *parent* resource doesn't exist —
  `/articles/1/relationships/tags` when there is no article 1).

---

## 5. Inclusion of related resources (`include`)

- An endpoint **MAY** return related resources by default, and **MAY** support the `include`
  query parameter for the client to customize which are returned.
- If an endpoint does *not* support `include`, it **MUST** respond `400 Bad Request` to any
  request carrying it.
- If it *does* support it and the client supplies it:
  - the response **MUST** be a compound document with an `included` key — "**even if that
    `included` key holds an empty array** (because the requested relationships are empty)";
  - the server **MUST NOT** include unrequested resource objects in `included`.
- The value **MUST** be a comma-separated list of *relationship paths*; a relationship path
  is a dot-separated list of relationship names. An empty value indicates that no related
  resources should be returned.
- If a server can't identify a relationship path, or doesn't support inclusion from a path,
  it **MUST** respond `400 Bad Request`.

```http
GET /articles/1?include=comments.author,ratings HTTP/1.1
Accept: application/vnd.api+json
```

Because compound documents require full linkage, intermediate resources of a multi-part path
come along too: `include=comments.author` yields the comments *and* each comment's author in
`included` (non-normative note). A server may also expose a nested relationship under a
direct alias (e.g. `commentAuthors`) to skip intermediates (non-normative note).

`include` also works on relationship endpoints
(`GET /articles/1/relationships/comments?include=comments.author` — identifiers as primary
data, full resources in `included`), and — per a non-normative note — this section applies to
any endpoint that responds with primary data regardless of request type (e.g. `POST`).

Compound document response example:

```http
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [{
    "type": "articles",
    "id": "1",
    "attributes": { "title": "JSON:API paints my bikeshed!" },
    "relationships": {
      "author": {
        "links": {
          "self": "http://example.com/articles/1/relationships/author",
          "related": "http://example.com/articles/1/author"
        },
        "data": { "type": "people", "id": "9" }
      },
      "comments": {
        "data": [
          { "type": "comments", "id": "5" },
          { "type": "comments", "id": "12" }
        ]
      }
    }
  }],
  "included": [
    { "type": "people", "id": "9", "attributes": { "firstName": "Dan" } },
    {
      "type": "comments", "id": "5",
      "attributes": { "body": "First!" },
      "relationships": { "author": { "data": { "type": "people", "id": "2" } } }
    },
    {
      "type": "comments", "id": "12",
      "attributes": { "body": "I like XML better" },
      "relationships": { "author": { "data": { "type": "people", "id": "9" } } }
    }
  ]
}
```

Note the deduplication: person `9` (article author *and* comment 12's author) appears exactly
once — a compound document **MUST NOT** include more than one resource object per `type`+`id`.

---

## 6. Sparse fieldsets (`fields[TYPE]`)

- A client **MAY** request that an endpoint return only specific fields, per resource type,
  with `fields[TYPE]` parameters.
- The value of any `fields[TYPE]` parameter **MUST** be a comma-separated list that "refers
  to the name(s) of the **fields** to be returned" — and *fields* is the defined term from
  [§3.2](#32-resource-objects): **attributes and relationships share one namespace**, so
  `fields[articles]=title,author` can name both an attribute and a relationship. An empty
  value indicates that *no* fields should be returned.
- If a client requests a restricted fieldset for a type, the endpoint **MUST NOT** include
  additional fields in resource objects of that type in the response.
- If a client does *not* specify a fieldset for a type, the server **MAY** send all fields,
  a subset, or *no* fields for that type. (Yes — the server is free to omit fields even
  without sparse fieldsets.)

```http
GET /articles?include=author&fields[articles]=title,body&fields[people]=name HTTP/1.1
Accept: application/vnd.api+json
```

(In practice `[` and `]` should be percent-encoded when serializing; servers **SHOULD**
accept unencoded square brackets in parameter names and, if they do, **MUST** treat such
requests as equivalent to the encoded form — spec appendix.)

Interactions worth knowing:

- Sparse fieldsets apply to *both* primary and included resources ("any endpoint that
  responds with resources as primary or included data" — non-normative note).
- Excluding a relationship via fieldsets is the *only* sanctioned exception to the full
  linkage requirement for compound documents ([§3.4](#34-compound-documents-included)).

---

## 7. Sorting (`sort`)

What the spec actually pins down here is narrower than most people assume.

**Normative rules:**

- A server **MAY** support sorting of resource collections according to one or more
  criteria ("sort fields").
- An endpoint **MAY** support a `sort` query parameter; its value **MUST** represent sort
  fields.
- An endpoint **MAY** support multiple comma-separated sort fields; they **SHOULD** be
  applied in the order specified.
- The sort order for each field **MUST** be ascending, unless prefixed with `-`
  (U+002D HYPHEN-MINUS), in which case it **MUST** be descending.
- "If the server does not support sorting as specified in the query parameter `sort`, it
  **MUST** return `400 Bad Request`." (Any unsupported sort field → 400.)
- If sorting is supported and requested, the server **MUST** return the top-level `data`
  array ordered per the criteria. The server **MAY** apply default sorting when `sort` is
  absent.

**Non-normative notes (recommendations only — quoted, because these are widely misread):**

> "Note: Although recommended, **sort fields do not necessarily need to correspond to
> resource attribute and relationship names**."

> "Note: It is recommended that dot-separated (U+002E FULL-STOP, '.') sort fields be used to
> request sorting based upon relationship attributes."

So `sort=relevance` (a computed score that is not an attribute) is fully conformant, and
`sort=author.name` is a *convention*, not spec grammar. What a "sort field" names is left to
the server; only the comma-list, the `-` prefix, ordering guarantees, and the 400 rule are
normative.

```http
GET /articles?sort=-created,title HTTP/1.1
Accept: application/vnd.api+json
```

Applies to any endpoint responding with a resource collection as primary data, regardless of
request type (non-normative note).

---

## 8. Pagination

### 8.1 What the base spec says (and deliberately doesn't)

**Normative:**

- A server **MAY** limit the resources returned to a subset ("page") of the whole set.
- A server **MAY** provide pagination links; they **MUST** appear in the `links` object that
  corresponds to the paginated collection (top-level `links` for primary data; the
  relationship object's `links` for a paginated relationship in a compound document).
- The following keys **MUST** be used for pagination links: `first`, `last`, `prev`, `next`.
- Keys **MUST** either be omitted or have a `null` value to indicate a link is unavailable.
- Concepts of order in the link names **MUST** remain consistent with the sorting rules.
- The `page` query parameter *family* is reserved for pagination; servers and clients
  **SHOULD** use these parameters for pagination operations.

**Left to the server (non-normative note, quoted):**

> "Note: JSON API is agnostic about the pagination strategy used by a server, but the `page`
> query parameter family can be used regardless of the strategy employed. For example, a
> page-based strategy might use query parameters such as `page[number]` and `page[size]`,
> while a cursor-based strategy might use `page[cursor]`."

So the base spec standardizes the *link names* and reserves the *parameter family* — nothing
else. `page[number]`/`page[size]`, `page[offset]`/`page[limit]`, `page[cursor]` are all
equally "conformant"; none is standard. That's exactly the gap the following profile fills.

### 8.2 The Cursor Pagination profile (opt-in PROFILE, not base spec)

> **Status.** This is a *profile* — pure implementation semantics, opt-in, safely ignorable
> by parties that don't recognize it. It is one of the two entries the JSON:API editors list
> on the official ["Extensions and Profiles" registry page](https://jsonapi.org/extensions/).
> Its full text lives at
> <https://jsonapi.org/profiles/ethanresnick/cursor-pagination/> (author: Ethan Resnick).
> All details below were verified against that page on 2026-07-09.
>
> Two verification caveats:
> 1. The profile's own text states "The url for this profile is
>    `http://jsonapi.org/profiles/ethanresnick/cursor-pagination/`" (http, trailing slash),
>    while the registry page lists the URI as
>    `https://jsonapi.org/profiles/ethanresnick/cursor-pagination` (https, no slash). Since
>    profile URIs in the `profile` media type parameter are compared as strings, pick one
>    canonical form (the registry's https form is the sensible choice) and use it
>    consistently.
> 2. The profile text mentions that its `page` meta members "can be aliased". *Aliasing* was
>    a mechanism in JSON:API 1.1 release candidates that does **not** exist in the final 1.1
>    spec (verified: the published 1.1 text contains no aliasing mechanism). Treat the member
>    names below as fixed.

A server advertising this profile responds with:

```http
Content-Type: application/vnd.api+json;profile="https://jsonapi.org/profiles/ethanresnick/cursor-pagination"
```

#### 8.2.1 Concepts

- A **cursor** is an opaque string, created by the server "using whatever method it likes",
  that divides the results list into items before it, items after it, and optionally one item
  "on" it. Cursor construction is entirely server-defined.
- **Terms** the profile defines: *paginated data* (the `data` array being paginated — either
  the top-level primary data or a relationship's linkage array), *pagination links* (the
  `links` object that's a sibling of the paginated data), *pagination metadata* (the `page`
  member of the `meta` object that's a sibling of the paginated data), *pagination item* (an
  entry in the paginated data), and *pagination item metadata* (the `page` member of an
  item's `meta`).
- The profile **reserves a `page` member in every JSON:API-defined meta object**. When
  present it **MUST** hold an object.

**Sorting requirement.** Pagination needs a total order:

- If the client's `sort` only partially orders the results, the server **MUST** apply
  additional sorting constraints — consistent with the client-requested ones — to produce a
  unique ordering (e.g. treat `?sort=age` as `?sort=age,id`), if it wishes to support
  pagination of that data.
- When the collection has no natural or requested order, the server **MUST** assign one if
  it wishes to support pagination.
- The server **MAY** reject pagination requests whose requested sort it cannot efficiently
  paginate; it then **MUST** respond per the *unsupported sort error* (8.2.5).

#### 8.2.2 Query parameters — exactly three

| Parameter | Rule |
|---|---|
| `page[size]` | If provided, **MUST** be a positive integer (formally: characters matching `^[0-9]+$` read as base-10 — the profile's error example treats `0` as invalid). Violation → *invalid query parameter error*. |
| `page[after]` | Optional; value is a cursor. Invalid cursor → *invalid query parameter error*. Returns results starting immediately **after** the cursor. |
| `page[before]` | Optional; value is a cursor. Invalid cursor → *invalid query parameter error*. Returns results ending immediately **before** the cursor. |

Page-size machinery:

- A server **MAY** define a per-endpoint "max page size" (implicitly infinity if it doesn't).
  `page[size]` exceeding it → *max page size exceeded error* (8.2.5).
- If `page[size]` is omitted, the server **MUST** choose a "default page size", an integer
  between 1 and the max page size inclusive.
- The "used page size" is `page[size]`, or the default when omitted. On any valid paginated
  request the number of items returned **MUST** equal the used page size — provided at least
  that many items satisfy the `page[after]`/`page[before]` constraints.

Positional semantics:

- With `page[after]`: the first item returned **MUST** be the item immediately after the
  cursor (if nothing falls after the cursor, the paginated data **MUST** be `[]`).
- With `page[before]`: the last item returned **MUST** be the item closest to, but still
  before, the cursor (if nothing falls before it → **MUST** be `[]`).
- With neither: the paginated data **MUST** start with the first item of the results list
  (empty list → **MUST** be `[]`).

```http
GET /people?page[size]=100&page[after]=abcde HTTP/1.1
Accept: application/vnd.api+json;profile="https://jsonapi.org/profiles/ethanresnick/cursor-pagination"
```

Worked example from the profile — results list ids `1, 5, 7, 8, 9`; cursor `abcde` falls on
id `5`; cursor `xxx` falls on id `9`:

```http
GET /example-data?page[after]=abcde&page[size]=2 HTTP/1.1
```

```json
{
  "links": {
    "prev": "/example-data?page[before]=yyy&page[size]=2",
    "next": "/example-data?page[after]=zzz&page[size]=2"
  },
  "data": [
    { "type": "examples", "id": "7", "meta": { "page": { "cursor": "yyy" } } },
    { "type": "examples", "id": "8", "meta": { "page": { "cursor": "zzz" } } }
  ]
}
```

**Range requests** (`page[after]` *and* `page[before]` together):

- Clients **MAY** combine both ("range pagination requests": everything after the `after`
  cursor up to the `before` cursor).
- Servers are **not required** to support them; if unsupported, the server **MUST** respond
  per the *range pagination not supported error* (8.2.5).
- On range requests the server **MUST** use its **max** page size as the default page size
  (used page size = `page[size]` or the max).
- If the matching results exceed the used page size, the server **MUST** respond with the
  same paginated data as if `page[before]` had not been provided, and **MUST** add
  `"rangeTruncated": true` to the pagination metadata:

```json
{
  "meta": { "page": { "rangeTruncated": true } },
  "links": {
    "prev": "/example-data?page[before]=yyy&page[size]=1",
    "next": "/example-data?page[after]=yyy&page[size]=1"
  },
  "data": [
    { "type": "examples", "id": "7" }
  ]
}
```

#### 8.2.3 Links under the profile

- Servers **MUST** include a `prev` and a `next` link for **each instance** of paginated
  data in a response (base spec merely allows them; the profile makes them mandatory —
  possibly with `null` values per the rules below).
- **RECOMMENDED**: include `first` and `last` when inexpensive to compute.
- If the request has no `page[before]`, the server **MUST** determine whether a next page
  exists and return `null` as the `next` link if not. Symmetrically, no `page[after]` →
  **MUST** determine whether a previous page exists and return `null` `prev` if not.
- In all other cases the server **SHOULD** set these links to `null` when it can
  *inexpensively* determine the current response is the first/last page — and when it can't
  cheaply know, it **MAY** emit a URI that simply returns `[]` as its paginated data (the
  client discovers the end by fetching it).

#### 8.2.4 Meta members (all under `page`)

| Location | Member | Rule |
|---|---|---|
| pagination item metadata (`data[i].meta.page`) | `cursor` | Server **MAY** send it on some or all items; if present it **MUST** hold a cursor that (at response time) falls on that item. Clients use it as a `page[after]`/`page[before]` value. |
| pagination metadata (`meta.page` sibling of the data) | `total` | **MAY**; integer; total number of items in the results list being paginated. |
| pagination metadata | `estimatedTotal` | **MAY**; if present **MUST** be an object, which **MAY** have one key `bestGuess` (integer best estimate). For when exact counts are costly. |
| pagination metadata | `rangeTruncated` | **MUST** be added (value `true`) when a range request's results were truncated (8.2.2). |
| error object `meta.page` | `maxSize` | **MUST** carry the max page size (integer) on the *max page size exceeded* error. |

```json
{
  "meta": { "page": { "total": 200 } },
  "data": [ { "type": "people", "id": "1" }, { "type": "people", "id": "2" } ]
}
```

#### 8.2.5 Error cases (all `400 Bad Request`)

| Error | Requirements |
|---|---|
| **Unsupported sort** | **MUST** send `400`; the document **MUST** contain an error object identifying the `sort` parameter as `source` and carrying a `type` link of `https://jsonapi.org/profiles/ethanresnick/cursor-pagination/unsupported-sort`. |
| **Max page size exceeded** | **MUST** send `400`; error object **MUST** identify `page[size]` as source, provide `maxSize` (integer) in the error's `meta.page`, and include a `type` link of `https://jsonapi.org/profiles/ethanresnick/cursor-pagination/max-size-exceeded`. |
| **Invalid parameter value** | **MUST** send `400` with an error object identifying the problematic parameter in `source`. |
| **Range pagination not supported** | **MUST** send `400`; error object **MUST** have a `type` link of `https://jsonapi.org/profiles/ethanresnick/cursor-pagination/range-pagination-not-supported`. |

Example (max size exceeded):

```http
HTTP/1.1 400 Bad Request
Content-Type: application/vnd.api+json;profile="https://jsonapi.org/profiles/ethanresnick/cursor-pagination"

{
  "errors": [{
    "status": "400",
    "title": "Page size requested is too large.",
    "detail": "You requested a size of 200, but 100 is the maximum.",
    "source": { "parameter": "page[size]" },
    "meta": { "page": { "maxSize": 100 } },
    "links": {
      "type": ["https://jsonapi.org/profiles/ethanresnick/cursor-pagination/max-size-exceeded"]
    }
  }]
}
```

(Note: the profile's own example renders the `type` link as an *array* of one URI. The base
1.1 spec defines `links.type` as *a link*; an array here is the profile example's rendering —
if you want strict base-spec shape, a single link value is the safer emission.)

---

## 9. Filtering (`filter`)

The base spec's entire normative text on filtering, verbatim:

> "The `filter` query parameter family is reserved for filtering data. Servers and clients
> **SHOULD** use these parameters for filtering operations."
>
> "Note: JSON API is agnostic about the strategies supported by a server."

That's it. **Filter semantics — operators, value syntax, combinators — are entirely
server-defined.** `filter[post]=1,2`, `filter[age][gt]=21`, `filter=fullTextQuery` are all
equally conformant, and none is standard. A profile is the sanctioned way to standardize a
filtering convention (the spec's profile section uses exactly this example).

The [Recommendations page](https://jsonapi.org/recommendations/) — **non-normative** —
suggests association-based filtering shaped like:

```http
GET /comments?filter[post]=1 HTTP/1.1
GET /comments?filter[post]=1,2 HTTP/1.1
GET /comments?filter[post]=1,2&filter[author]=12 HTTP/1.1
```

Also relevant: the query-parameter-family grammar allows bracketed dot-paths, and a
non-normative note in the spec shows `filter[author.status]=active` as an intended pattern
for relationship-path filtering.

---

## 10. Writes: creating, updating, deleting

Umbrella rules:

- A server **MAY** allow creation, modification, deletion of resources of a given type —
  all optional capabilities.
- "A request **MUST** completely succeed or fail (in a single 'transaction'). No partial
  updates are allowed."
- Request documents are typed: "**`type` is always required**" in every resource object, in
  requests and responses alike (the spec has a dedicated note explaining why — see
  [§12](#12-the-commonly-misread-spots), entry 5).

### 10.1 Creating resources (POST)

```http
POST /photos HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json

{
  "data": {
    "type": "photos",
    "attributes": {
      "title": "Ember Hamster",
      "src": "http://example.com/images/productivity.png"
    },
    "relationships": {
      "photographer": {
        "data": { "type": "people", "id": "9" }
      }
    }
  }
}
```

- The request **MUST** include a *single resource object* as primary data, which **MUST**
  contain at least a `type` member.
- Any relationship provided **MUST** be a relationship object with a `data` member (the
  linkage the new resource is to have). **The base spec has no "sidepost"/nested-create:**
  you can only *link* to resources, identified by `type`+`id` (or `type`+`lid` for other new
  resources in the same document). To create multiple related resources atomically, use the
  [Atomic Operations extension](https://jsonapi.org/ext/atomic/) (`ext` URI
  `https://jsonapi.org/ext/atomic`, namespace `atomic`): POST an `atomic:operations` array of
  `add`/`update`/`remove` operations, processed in order, all-or-nothing, with results
  returned positionally in `atomic:results`.

**Client-generated IDs:**

- A server **MAY** accept a client-generated ID, supplied as `id`, whose value **MUST** be a
  universally unique identifier; the client **SHOULD** use a properly generated RFC 4122 UUID.
- A server **MUST** return `403 Forbidden` for an unsupported request to create with a
  client-generated ID.
- A server **MUST** return `409 Conflict` if the client-generated ID already exists.

**Response matrix for POST:**

| Case | Response |
|---|---|
| Created, and the server changed the resource in any way (e.g. assigned `id`) | **MUST** `201 Created` + document with the resource as primary data. **SHOULD** include a `Location` header; if the resource object has a `self` link *and* `Location` is given, they **MUST** match. |
| Created, server did *not* change the resource at all | **MUST** return either `201` + document (which **MAY** omit primary data) or `204 No Content` with no document. (Only possible with client-generated IDs.) |
| Accepted for async processing, not done yet | **MUST** `202 Accepted`. |
| Unsupported create request | **MAY** `403 Forbidden`. |
| Request references a related resource that doesn't exist | **MUST** `404 Not Found`. |
| Client-generated ID already exists | **MUST** `409 Conflict`. |
| Body's `type` is not among the endpoint collection's type(s) | **MUST** `409 Conflict`. (For conflicts, the server **SHOULD** include error details.) |

```http
HTTP/1.1 201 Created
Location: http://example.com/photos/550e8400-e29b-41d4-a716-446655440000
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "photos",
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "attributes": {
      "title": "Ember Hamster",
      "src": "http://example.com/images/productivity.png"
    },
    "links": { "self": "http://example.com/photos/550e8400-e29b-41d4-a716-446655440000" }
  }
}
```

### 10.2 Updating resources (PATCH — not PUT)

```http
PATCH /articles/1 HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json

{
  "data": {
    "type": "articles",
    "id": "1",
    "attributes": { "title": "To TDD or Not" }
  }
}
```

- The request **MUST** include a single resource object as primary data, which **MUST**
  contain `type` and `id`.
- **Attributes:** any or all **MAY** be included. "If a request does not include all of the
  attributes for a resource, the server **MUST** interpret the missing attributes as if they
  were included with their current values. The server **MUST NOT** interpret missing
  attributes as `null` values." (Partial-update semantics are mandatory; to null a field you
  must send it explicitly as `null`.)
- **Relationships:** same rule — missing relationships **MUST** be treated as unchanged,
  **MUST NOT** be treated as null/empty. Any relationship that *is* provided **MUST** be a
  relationship object with a `data` member, and the relationship's value **will be replaced**
  with that linkage. A to-many relationship in a PATCH is therefore a *complete replacement*;
  a server **MAY** reject full replacement, in which case it **MUST** reject the entire
  update and return `403 Forbidden`.

**Response matrix for PATCH:**

| Case | Response |
|---|---|
| Accepted, but server also changed the resource in ways *other than* requested (e.g. bumped `updatedAt`) | **MUST** `200 OK` + document with the updated resource as primary data. |
| Success, no changes beyond the request | **MUST** return either `200 OK` + document (which **MAY** omit primary data, e.g. only `meta`) or `204 No Content` with no document. |
| Async | **MUST** `202 Accepted`. |
| Unsupported update | **MUST** `403 Forbidden`. |
| Target resource does not exist | **MUST** `404 Not Found`. |
| A referenced related resource does not exist | **MUST** `404 Not Found`. |
| Violates other server constraints (e.g. uniqueness) | **MAY** `409 Conflict`. |
| Body's `type` or `id` does not match the endpoint | **MUST** `409 Conflict`. |

(`PUT` appears nowhere in the spec. The FAQ: partial update via `PUT` "is not allowed by the
HTTP specification… The correct method for partial updates, therefore, is `PATCH`". For
legacy clients lacking PATCH, the non-normative Recommendations page suggests honoring
`POST` + `X-HTTP-Method-Override: PATCH`.)

### 10.3 Updating relationships directly (relationship links)

Relationships can be edited at the URL from a relationship's `self` link without touching
the resources themselves.

**To-one** — `PATCH` with a top-level `data` that **MUST** be one of: a resource identifier
object, or `null` (to clear):

```http
PATCH /articles/1/relationships/author HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json

{ "data": { "type": "people", "id": "12" } }
```

**To-many** — `PATCH`, `POST`, or `DELETE`; for all three, the body **MUST** contain a
`data` member whose value is an empty array or an array of resource identifier objects:

| Method | Semantics |
|---|---|
| `PATCH` | Full replacement. Server **MUST** either completely replace every member, return an appropriate error if some resources can't be found/accessed, or return `403 Forbidden` if it disallows full replacement. `{ "data": [] }` clears the relationship. |
| `POST` | Add members. Server **MUST** add the specified members unless already present; if a given `type`+`id` is already there it **MUST NOT** add it again. If all specified resources are added or already present → **MUST** return a successful response (idempotent-ish by design, to defuse races). |
| `DELETE` | Remove members. Server **MUST** delete the specified members or return `403 Forbidden`. If all specified resources were removed or already absent → **MUST** return a successful response. |

```http
POST /articles/1/relationships/comments HTTP/1.1
Content-Type: application/vnd.api+json
Accept: application/vnd.api+json

{ "data": [ { "type": "comments", "id": "123" } ] }
```

**Relationship-update responses:** mirror resource updates — **MUST** `200 OK` + updated
linkage as primary data if the server changed the relationship beyond the request; otherwise
**MUST** be `200` + document (possibly only `meta`) or `204 No Content`; **MUST** `202` for
async; **MUST** `403` for unsupported. Non-normative note: `204` is the appropriate response
to a to-many `POST` whose members already exist, and to a `DELETE` whose members are already
gone. (If a to-one relationship update succeeds, the server **MUST** return a successful
response.)

### 10.4 Deleting resources

```http
DELETE /photos/1 HTTP/1.1
Accept: application/vnd.api+json
```

| Case | Response |
|---|---|
| Success | **MUST** return either `200 OK` + document with no primary data (e.g. just `meta`) or `204 No Content` with no document. (`200` with a meta-only document is a **MAY** option.) |
| Async | **MUST** `202 Accepted`. |
| Resource doesn't exist | **SHOULD** `404 Not Found` (note: SHOULD, not MUST — the only soft 404 in the spec; tombstoning/idempotent deletes are permissible). |

For all write sections, the spec repeats: a server **MAY** respond with other HTTP status
codes, **MAY** include error details, and **MUST** prepare responses per HTTP semantics.

### 10.5 Query parameter rules (applies everywhere)

- A "query parameter family" is all parameters whose name starts with a base name followed by
  zero or more instances of `[]`, `[memberName]`, or `[dotted.member.names]`. `filter`,
  `filter[x]`, `filter[x][y]`, `filter[x.y]` are one family; `filter[_]` is invalid because
  `_` is not a valid member name standing alone.
- **Extension-defined** query parameters **MUST** be prefixed `namespace:` and the rest of
  the base name **MUST** be only `a-z`.
- **Implementation-specific** query parameters **MUST** come from a family whose base name is
  a legal member name *and contains at least one non a-z character* (outside U+0061–U+007A).
  It is **RECOMMENDED** to satisfy this with a capital letter (camelCase).
- "If a server encounters a query parameter that does not follow the naming conventions
  above, **or** the server does not know how to process it as a query parameter from this
  specification, it **MUST** return `400 Bad Request`." (1.1 tightened this from 1.0's "and"
  to "or".)

So: `?includeDeleted=1` — legal shape (has a capital) but still 400 unless your server
actually knows it; `?embed=author` — non-conformant *name* for a custom parameter (all
lowercase a-z) and **MUST** be rejected with 400.

---

## 11. Errors

### 11.1 Processing

- A server **MAY** stop at the first problem or **MAY** continue and collect several (e.g.
  many validation failures in one response).
- With multiple problems in one response, the most generally applicable HTTP status code
  **SHOULD** be used (e.g. `400` for mixed 4xx, `500` for mixed 5xx).

### 11.2 Error objects

Error objects **MUST** be returned as an array keyed by `errors` at the document top level.
(Never a bare object; never mixed with `data`.)

An error object **MAY** have the following members, and **MUST** contain at least one of them:

| Member | Meaning / force |
|---|---|
| `id` | unique identifier for this occurrence of the problem |
| `links.about` | link to details about this occurrence; **SHOULD** dereference to a human-readable description |
| `links.type` | link identifying the *type* of error; **SHOULD** dereference to a general explanation *(new in 1.1)* |
| `status` | applicable HTTP status code **as a string**; "This **SHOULD** be provided." |
| `code` | application-specific error code, string |
| `title` | short human-readable summary; **SHOULD NOT** change between occurrences (except localization) |
| `detail` | human-readable explanation of this occurrence (localizable) |
| `source` | object referencing the error's primary source; **SHOULD** include one of the following or be omitted: `pointer` (JSON Pointer, RFC 6901, into the *request document*, e.g. `/data/attributes/title` — it **MUST** point to a value that actually exists; if not, the client **SHOULD** ignore it), `parameter` (name of the offending query parameter), `header` (name of a single offending request header — *new in 1.1*) |
| `meta` | non-standard meta-information |

```http
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/vnd.api+json

{
  "errors": [
    {
      "status": "422",
      "code": "VALIDATION_ERROR",
      "title": "Invalid attribute",
      "detail": "Title must contain at least three characters.",
      "source": { "pointer": "/data/attributes/title" }
    },
    {
      "status": "422",
      "title": "Invalid attribute",
      "detail": "Body cannot be blank.",
      "source": { "pointer": "/data/attributes/body" }
    }
  ]
}
```

Mandatory error-status pairings worth memorizing (all from earlier sections):
`400` — unsupported/unknown `include` path, unsupported `sort`, malformed/unknown query
parameter; `403` — unsupported client-generated ID, disallowed to-many full replacement,
unsupported create/update; `404` — missing fetched resource (minus the null case), missing
relationship URL, referenced related resource missing, target of a modification missing;
`409` — duplicate client-generated ID, `type` not matching endpoint collection, `type`/`id`
mismatch on PATCH; `415`/`406` — media type violations ([§2.4](#24-server-responsibilities--the-415406-decision-table)).

---

## 12. The commonly-misread spots

Each entry: the misreading → what the spec actually says.

### 1. "Sort fields must be attribute names, and `author.name` is spec syntax"

**Misreading.** Validating `sort` values against the attributes list and treating dotted
paths as normative grammar.

**Actually:** both points live in *non-normative notes*:

> "Although recommended, sort fields do not necessarily need to correspond to resource
> attribute and relationship names." — note, recommendation only.

> "It is recommended that dot-separated … sort fields be used to request sorting based upon
> relationship attributes." — note, recommendation only.

Normatively, a "sort field" is just a criterion the server names. What *is* normative: comma
separation, `-` prefix **MUST** mean descending / bare **MUST** mean ascending, ordering of
the `data` array **MUST** follow the criteria, and unsupported sort → **MUST** `400`.

### 2. "JSON:API defines filter operators"

**Misreading.** Assuming `filter[age][gt]`, `filter[title][contains]`, etc. are "the JSON:API
way".

**Actually:** the base spec's whole treatment is: "The `filter` query parameter family is
reserved for filtering data. Servers and clients **SHOULD** use these parameters for
filtering operations." plus a note that it "is agnostic about the strategies supported by a
server". Everything beyond the family name is implementation semantics (standardizable via a
profile). Even `filter[post]=1,2` is only a suggestion on the non-normative Recommendations
page.

### 3. "Sparse fieldset values are server-defined like sort/filter"

**Misreading.** Carrying the sort/filter looseness over to `fields[TYPE]`.

**Actually:** the opposite. The value **MUST** be "a comma-separated … list that refers to
the name(s) of the fields to be returned", and "fields" is a *defined term*: "A resource
object's attributes and its relationships are collectively called its 'fields'." So fieldset
values are, by definition, the resource's actual field names — one namespace covering both
attributes and relationships (you can drop a relationship with `fields[]` too, which is also
the one sanctioned way to break full linkage in a compound document).

### 4. "We can add our own media type parameter (e.g. `;version=2`)"

**Misreading.** Using a custom media type parameter for versioning or feature flags.

**Actually:** "The JSON:API media type **MUST NOT** be specified with any media type
parameters other than `ext` and `profile`." And enforcement is mandatory, not optional: such
a `Content-Type` **MUST** get `415`; `Accept` instances so modified **MUST** be ignored, and
if all instances are so modified the server **MUST** send `406`. Version signals belong in a
header, the URL, or a profile URI.

### 5. "`type` can be omitted from request bodies since the endpoint implies it"

**Misreading.** Accepting `{ "data": { "attributes": { … } } }` on POST because the URL
already says what's being created.

**Actually:** request documents are typed. POST: "The resource object **MUST** contain at
least a `type` member." PATCH: "The resource object **MUST** contain `type` and `id`
members." The spec's note is explicit about the design choice:

> "The `type` member is required in every resource object throughout requests and responses
> in JSON:API. … picking and choosing when it is required would be confusing … Therefore, to
> improve consistency and minimize confusion, `type` is always required."

Corollaries: POST with a `type` not matching the endpoint's collection → **MUST** `409`;
PATCH whose `type`/`id` don't match the endpoint → **MUST** `409`.

### 6. "Updates are PUT (or PUT and PATCH are interchangeable)"

**Misreading.** Exposing `PUT /articles/1` for updates.

**Actually:** the spec defines updates *only* for `PATCH`: "A resource can be updated by
sending a `PATCH` request…". `PUT` is absent by design (FAQ: partial update via PUT violates
HTTP semantics; "The correct method for partial updates, therefore, is PATCH"). And PATCH
semantics are pinned down: missing attributes/relationships **MUST** be read as "current
value", **MUST NOT** be read as null. A to-many relationship included in a PATCH is a full
replacement, which the server **MAY** refuse — but then **MUST** reject the *entire* update
with `403`.

### 7. "Unknown query params can be silently ignored" / "any custom param name is fine"

**Misreading.** Either dropping unrecognized parameters on the floor, or naming a custom
parameter `embed`/`pretty` (all lowercase).

**Actually:** two interlocking rules. (a) Reserved families have hard 400s: unsupported
`include` → **MUST** `400`; unresolvable include path → **MUST** `400`; unsupported `sort` →
**MUST** `400`. (b) For everything else: implementation-specific parameters **MUST** come
from a family whose base name contains at least one **non a-z** character (**RECOMMENDED**: a
capital letter) — the all-lowercase namespace is reserved for future spec use — and "If a
server encounters a query parameter that does not follow the naming conventions above, or the
server does not know how to process it …, it **MUST** return `400 Bad Request`." Silence is
non-conformant either way.

### 8. "Missing to-one related resource → 404" / "empty collection → 404"

**Misreading.** Returning `404` for `GET /articles/1/author` when article 1 has no author,
or for an empty collection.

**Actually:** `404` is **MUST** only for "a single resource that does not exist, *except*
when the request warrants a `200 OK` response with `null` as the primary data" — and the
null case is precisely a URL that "might correspond to a single resource, but doesn't
currently" (empty to-one related link). Empty collections are `200` + `data: []`; empty
relationships fetched via relationship links are `200` + `null`/`[]` (**MUST**, per the
fetching-relationships rules). `404` on a relationship URL is for when the *URL* (e.g. the
parent) doesn't exist.

### 9. "`included` may be omitted when the requested includes come back empty"

**Misreading.** Dropping the `included` key when `?include=comments` matches nothing.

**Actually (1.1):** "The server's response **MUST** be a compound document with an
`included` key — **even if that `included` key holds an empty array** (because the requested
relationships are empty)." Also in this family: the server **MUST NOT** put unrequested
resources in `included` when the client used `include`, and (independent of `include`) a
document with no top-level `data` **MUST NOT** have `included` at all.

### 10. "POST to a to-many relationship replaces it" / "adding a duplicate is an error"

**Misreading.** Treating relationship `POST` like `PATCH`, or erroring when a posted member
already exists.

**Actually:** `POST` on a to-many relationship link is *append with dedup*: the server
**MUST** add the specified members "unless they are already present", **MUST NOT** add a
duplicate, and if everything is added *or already present* it **MUST** return a successful
response (the note recommends `204` for the already-present case). Full replacement is
`PATCH`'s job — and refusing full replacement (allowed) means `403` for the whole request.

---

## 13. JSON:API 1.0 → 1.1 differences

JSON:API evolves additively, so 1.1 only adds. Differences below were verified by comparing
the published 1.0 and 1.1 texts (there is no official "changes" section on either page):

- **Extensions & profiles framework + `ext`/`profile` media type parameters.** 1.0 forbade
  *all* media type parameters (Content-Type with any parameter → 415; Accept instances with
  any parameter → ignore/406). 1.1 carves out `ext` and `profile` and defines the whole
  negotiation machinery of [§2](#2-media-type--content-negotiation). (A 1.0 server therefore
  415s any `ext`/`profile` request.)
- **`lid` (local IDs)** for client-created resources and their linkage within one document —
  did not exist in 1.0.
- **Richer link representation.** 1.0 links were a string or a link object with only
  `href` + `meta`. 1.1 adds the `null` link form and the link-object members `rel`,
  `describedby`, `title`, `type`, `hreflang`; strings are now formally URI-references.
- **Top-level `describedby` link** (description documents such as OpenAPI/JSON Schema) — new
  in 1.1, plus the `self`-link-as-link-object guidance when extensions/profiles are applied.
- **`jsonapi` object members `ext` and `profile`** (1.0 had only `version` and `meta`), with
  the rule that they **MUST NOT** be used for content negotiation.
- **Error object additions:** `links.type` (error-type link) and `source.header`; `source`
  gained "SHOULD include one of … or be omitted" and the pointer-must-exist rule; 1.1 also
  added "**MUST** contain at least one of" the listed members (1.0 only said MAY-have).
- **@-Members** (`@`-prefixed member names as opaque implementation semantics) — in 1.0, `@`
  was simply a reserved character.
- **Query parameter formalization:** the "query parameter family" concept, extension-specific
  parameter rules, and the implementation-specific non-a-z naming rule are all new; the
  unknown-parameter 400 rule was tightened from 1.0's "does not follow the naming conventions
  above, **and** the server does not know how to process it" to 1.1's "… **or** the server
  does not know how to process it".
- **`include` tightening:** the requirement that a supported-and-supplied `include` produce a
  compound document with an `included` key *even when empty* is new; 1.1 also spells out that
  an empty `include`/`fields[TYPE]` value means "nothing".
- **Assorted clarifications** promoted into normative text (e.g. `201`/`200` responses that
  **MAY** omit primary data, relationship-object pagination links paginating the linkage,
  the appendix on query-parameter parsing and unencoded square brackets).

Note: some things people attribute to 1.1 are already in the (living) 1.0 page — e.g. the
sparse-fieldsets exception to full linkage and the SHOULD-404 on deleting a missing resource
appear in the 1.0 text as published today.

---

## 14. Bibliography

All sources fetched and read in full on **2026-07-09**:

| URL | What it covers |
|---|---|
| <https://jsonapi.org/format/> | The JSON:API v1.1 specification (the primary source for §§2–11). |
| <https://jsonapi.org/format/1.0/> | The 1.0 specification; used to derive §13 by direct comparison (neither page carries an official changelog section). |
| <https://jsonapi.org/extensions/> | The "Extensions and Profiles" page — the editors' curated registry. Lists exactly one extension (Atomic Operations, URI `https://jsonapi.org/ext/atomic`, namespace `atomic`) and one profile (Cursor Pagination, URI `https://jsonapi.org/profiles/ethanresnick/cursor-pagination`). Also explains the extension-vs-profile distinction. |
| <https://jsonapi.org/profiles/ethanresnick/cursor-pagination/> | Full text of the Cursor Pagination profile (§8.2). |
| <https://jsonapi.org/ext/atomic/> | Full text of the Atomic Operations extension (summarized in §10.1). |
| <https://jsonapi.org/recommendations/> | Non-normative recommendations: naming, URL design, filtering suggestions, recommended links, `X-HTTP-Method-Override: PATCH`, ISO 8601 dates, async-processing pattern (202 + job resource + 303), and how to author a profile. |
| <https://jsonapi.org/faq/> | FAQ; source for the "Where's PUT?" rationale, `Allow`-header method discovery, and "no requirements about URI structure". |

**Could not be verified:** the profiles registry *index* at `https://jsonapi.org/profiles/`
currently returns a GitHub Pages 404 ("File not found"); the working registry listing is the
Extensions and Profiles page above. Two internal inconsistencies in the profile document are
flagged inline in §8.2 (its `http://` self-declared URI vs. the registry's `https://` form,
and its reference to the "aliasing" mechanism that was dropped from the final 1.1 spec).
