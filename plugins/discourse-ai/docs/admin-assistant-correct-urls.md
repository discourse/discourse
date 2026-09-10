# Correct URLs in the Admin Assistant

Research proposal, 2026-09-10. The first milestone is implemented; see
[Navigation destinations](navigation-destinations.md) for the registration API and
current scope. Pre-display validation remains proposed work. The current-behavior
section below records the baseline investigated before implementation.

## Recommendation

Give the assistant a searchable catalog of verified local destinations and return
canonical URLs from its existing resource tools. Add deterministic validation before
displaying links if the requirement is that every emitted local link is verified.
Prompt instructions alone cannot enforce that requirement.

This can guarantee that a link belongs to a supported destination and that its
parameters were validated at generation time. It cannot guarantee that the model
chose the best destination for the question, or that permissions and resources will
remain unchanged when the administrator clicks it.

## Current behavior and integration points

- `lib/agents/discourse_admin_assistant.rb` instructs the model to construct absolute
  Markdown links using `{site_url}`, with `/new-invite` as its only example. It has
  no local navigation lookup tool.
- `lib/agents/bot_context.rb` defaults `site_url` to `Discourse.base_url`.
  Core's `lib/discourse.rb` includes the installation's base path in that value.
- `lib/agents/tools/search_settings.rb` returns setting names and sometimes
  descriptions, but no setting URLs. `list_categories.rb` returns category IDs and
  slugs without URLs; `list_reviewables.rb` similarly has no URL field.
- `lib/agents/tools/discourse_meta_search.rb` already constructs source URLs from
  returned topic IDs and post numbers. Those are citations on Meta, not evidence
  that a corresponding administration path exists on the local installation.
- Core's `frontend/discourse/app/lib/sidebar/admin-nav-map.js` supplies semantic
  names, translated labels, route names, route models, and some search keywords.
  For example, the review queue uses the `review` route; not every administrative
  task belongs under `/admin`.
- `frontend/discourse/admin/routes/admin-route-map.js` defines the actual Ember
  paths, including `/admin/site_settings` and its category subroute. Plugin routes
  live in separate maps. `frontend/discourse/app/lib/admin-utilities.js` already
  uses `router.urlFor` to check whether plugin administration routes can resolve.
- `lib/agents/bot.rb`, in `Bot#reply`, forwards generated text chunks through
  `update_blk` before the final response is assembled. Forum persistence and chat
  streaming live in `lib/ai_bot/playground.rb` and `lib/ai_bot/chat_streamer.rb`.
  Checking only the saved final post would leave streamed links unchecked.

Paths above are relative to this plugin unless explicitly marked as core.

## Proposed design

1. Introduce a small server-side destination catalog in this plugin. Each entry
   has a stable ID, title, description, search aliases, URL builder, and availability
   predicate. Start with the admin sidebar's common destinations, settings, invites,
   categories, tags, and review queue. Do not expose arbitrary route interpolation
   or accept model-supplied hostnames. Unsupported destinations return no match.
2. Add a read-only `search_discourse_navigation(query)` tool returning a handful of
   matching entries with canonical absolute URLs. Match names, descriptions, and
   aliases deterministically first; embeddings are unnecessary for an initial small
   catalog. Include enough purpose information to distinguish similar destinations.
3. Add canonical URLs to settings and resource tool results using the same builders
   and existing model URL methods where suitable. Validate resource existence and
   access using the requesting user's Guardian. Preserve the configured base path
   exactly once and encode query parameters. A setting result can link to
   `/admin/site_settings/category/all_settings?filter=SETTING_NAME`, with the name
   obtained from settings lookup rather than invented by the model.
4. Instruct the assistant to reuse returned URLs exactly, and to search navigation
   before linking to a destination it has not resolved. Keep Meta citations separate:
   a documentation URL should not be rewritten onto the local site's hostname.
5. For enforced correctness, keep a server-owned set of resolved destinations for
   the response. Parse outgoing links with Markdown-aware handling and permit local
   targets only when their normalized URL and parameters match a verified entry.
   Revalidate links reused from earlier turns. On failure, allow one bounded repair
   attempt, then retain descriptive text without an unverified clickable target.
   Record rejected links for improving coverage. Never silently substitute an
   unrelated page merely because its URL exists.

For the first enforced implementation, buffer the Admin Assistant's generated
prose until validation finishes. This trades text streaming for a much simpler
correctness boundary. Continue tool progress separately, ensuring any tool-generated
links also have trusted builders. Apply the validated text consistently to chat,
forum posts, and conversation history. An incremental Markdown parser could later
restore streaming, but must handle links split across chunks, reference links,
autolinks, HTML anchors, and cancellation without exposing unchecked targets.

An alternative is to have the model emit opaque destination references and resolve
those into links in application code. This avoids copying URLs through the model,
but requires a new output convention and still needs to reject raw links that bypass
it. Evaluate this if Markdown validation proves too complex.

## Keeping the catalog accurate

The admin navigation map is a useful seed, but it contains frontend route names,
not a ready-to-use Ruby URL registry. Avoid parsing JavaScript with regular
expressions or treating client-supplied URL lists as authoritative.

For the initial curated catalog, pair each entry with its Ember route and test the
builder's output against `router.urlFor`, including models and query parameters.
Browser navigation tests should verify representative pages actually load. Route
recognition alone does not validate dynamic IDs, feature availability, or query
parameter semantics. Rails route recognition or an HTTP 200 alone is insufficient
because the server and client route maps are separate and some server paths include
wildcards.

Longer term, extract shared declarative destination metadata consumed by navigation
and the assistant, or generate a route manifest at build time. Both require more
core integration than an initial catalog. Provide explicit plugin registration and
availability predicates; omit unavailable plugin destinations and entries that launch
actions instead of navigating. Keep authorization checks at resolution time.

### Private plugin destinations

Plugin registration belongs in the first milestone, rather than being deferred
until a shared navigation manifest exists. Public source code and public
documentation cannot enumerate every destination on a running installation.

Prefer a generic core plugin registry for navigation destinations, consumed by the
assistant. This adjusts the initial plugin-local catalog design: the AI plugin can
own its search and validation logic, while destination registration has no dependency
on AI plugin load order. Each contributing plugin owns its entries, route builders,
translated labels, search aliases, availability checks, and route contract tests.
Use synthetic plugin entries in public tests; keep private destination definitions
and their integration tests in the private plugin.

A registration should carry a namespaced destination ID, a description of what the
page enables, a relative-path builder, and a predicate evaluated with the current
site and requesting Guardian. For example, a plugin-owned account page could be
discoverable using aliases such as billing, subscription, invoices, and change plan.
These are proposed registration fields, not an API that already exists.

At lookup time, collect core and loaded-plugin entries, exclude disabled or
unauthorized entries, construct absolute URLs using the current site's base URL,
and record returned destinations in the same verification set as core destinations.
Do not build a global cross-site cache of resolved URLs or authorization results.
The plugin's server authorization remains authoritative; a visible sidebar link
alone does not prove access. Search should explain the page's capabilities without
returning account data or implementation source.

Distinguish public product/pricing questions from requests to manage the current
site's subscription or account. The latter should search local navigation first;
the current assistant instruction sending billing questions directly to the public
pricing page needs narrowing. If the contributing plugin is absent, do not invent
an account-management path or substitute the public pricing page as though it
managed the local account.

Test registration with the AI plugin absent, both plugin load orders, multiple
sites in one process, denied users, base-path installations, and plugin absence or
disablement. In the private plugin, verify that its URL builder agrees with the
Ember route and that its actual page loads for an authorized administrator.

## Alternatives

| Approach | Benefit | Limitation |
| --- | --- | --- |
| Add more examples to the prompt | Smallest change | Drifts with routes; no enforcement |
| Put every route in the prompt | Broad path coverage | Token overhead; lacks task meaning and availability |
| Retrieve instructions from Meta | Useful factual guidance | May describe old routes or another installation |
| Probe generated URLs over HTTP | Can detect some missing pages | Authentication, redirects, and shell responses obscure validity |
| Catalog, tool results, and output validation | Explicit source and enforcement | Catalog maintenance and streaming integration |

## Delivery and verification

First ship the catalog, lookup tool, enriched settings results, and prompt changes
as an accuracy improvement. Do not describe that milestone as an absolute guarantee.
Then implement pre-display validation before declaring the invariant enforced.

Test exact setting filters, root and subfolder installations, encoded parameters,
unknown destinations, disabled plugins, denied access, deleted resources, and route
drift. For enforcement, test malformed Markdown, invented local and protocol-relative
URLs, unexpected query strings, alternate hosts presented as local destinations,
links split across chunks, repair exhaustion, cancellation, and both chat and forum
output. A separate citation policy can require Meta and official website links to
come from retrieved sources; arbitrary external citations are outside the local
navigation guarantee.

Build a held-out evaluation set covering requests such as changing the site title,
configuring authentication, creating an invite, opening the review queue, managing
themes, and configuring an unavailable plugin. Include misleading old URLs in user
input and retrieved text. Compare baseline and proposed behavior across supported
models. Measure destination relevance, invalid displayed links, omitted useful links,
lookup success, repair rate, latency, and token usage. Omitting every link must not
count as successful assistance. No model evaluation or runtime tests were run for
this research-only proposal.

## External research

- [Ember: Defining your routes](https://guides.emberjs.com/release/routing/defining-your-routes/)
  explains explicit paths, nested routes, and dynamic segments. This supports using
  route metadata and URL generation rather than guessing paths from page names.
- [Anthropic: Writing effective tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
  recommends focused tools, meaningful returned context, and evaluations grounded
  in realistic tasks. Enriching existing lookup results and adding a focused
  navigation search follows those principles. The deterministic output validator
  is this proposal's design recommendation, not a guarantee supplied by that article.
