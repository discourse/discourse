# ui-kit component groups

A ui-kit component group is a directory under `frontend/discourse/app/ui-kit/`
that ships one cohesive piece of UI machinery — a select, a dock — as a small
set of modules with one clear public surface. Groups follow a three-tier
structure, and the tiers are enforced, not aspirational.

## The three tiers

**1. One core component per group.** The single real implementation, exported
from the group's entry module (`ui-kit/select`, `ui-kit/panel-dock`). It owns
the group's capability surface: everything the group can do is expressible
through this component's public API, and its signature is the group's
contract.

**2. Facades ("recipes") — any number, public.** Thin, named compositions of
the core for a recurring use case: a facade wires a data source, an item
shape, and defaults, adding _configuration, not capability_. Facades obey one
hard constraint:

> A facade may only consume the core's public API. If a facade needs
> `-internals/`, it is not a facade — it is evidence the core's public API is
> missing a capability. Promote that capability into the core's API; never
> let the recipe reach inside.

This constraint is what keeps the platform honest. Every core-shipped facade
is a living proof that the public API is sufficient, which is exactly the
guarantee plugin authors need: a plugin-authored recipe has precisely the
same power as a core one, because core recipes were never allowed privileged
access.

**3. Private collaborators in `-internals/`.** Everything else — engines,
chassis, coordinators, parts. Modules under a group's `-internals/` directory
are importable only from within that group (and from test files). The
`discourse-local/no-cross-group-internals` ESLint rule enforces this
boundary wherever the specifier's fixed text already proves the reach-in:
static imports, re-exports, literal dynamic imports, and interpolated
dynamic imports whose fixed prefix names an `-internals` path. A specifier
whose _group_ is only known at runtime is beyond static analysis; writing
one against an internals path is the same violation, just one only review
can catch.

Note the enforcement split between the tiers: the lint rule guards the
_group boundary_ (tier 3). The facade constraint (tier 2) is a review-time
rule — a facade lives inside its group, where internals imports are
lexically legal, so keeping recipes on the public API is the reviewer's
gate until a structural convention for recipe placement exists.

## Second core or facade?

Two components may share private machinery without one being a facade of the
other: float-kit's menu and tooltip are two cores over shared internals,
because neither is expressible through the other's public API. That is the
litmus test:

- Buildable purely on the other component's public API → it is a facade.
- Not buildable that way → it is either a second core over shared internals,
  or a missing capability to promote into the existing core. Decide which,
  deliberately.

## Practical rules

- New shared machinery for a group starts in `-internals/` and is promoted to
  public API only when a consumer outside the group needs it — expressed as
  core component arguments or yields, never as a directly importable internal
  module.
- Tests may import internals; that is why they are exempt from the lint rule.
  Production code never gets an exemption — a "just this once" import is the
  policy failing, not an edge case.
- The internals boundary is per group. One group importing another group's
  internals is exactly as forbidden as app code doing it.
