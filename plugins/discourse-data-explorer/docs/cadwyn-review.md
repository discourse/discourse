# Cadwyn Source Review — Design Ideas for a Rails JSON:API Date-Based Versioning Layer

**Reviewed: Cadwyn 7.1.0, commit `22241f2d9d92e36d0222fd2536effb43b06e3b6e` (2026-07-06), on 2026-07-07.**

Version established from `pyproject.toml` (`version = "7.1.0"`), `CHANGELOG.md` (top released entry `[7.1.0]`), and `git -C <repo> log -1`. All line citations are against that checkout. Where the docs and the code disagree, I flag it and prefer the code.

This document is written for a team building a home-grown, Stripe-style, date-based versioning layer ("JSON:API Kit") on **Ruby on Rails + jsonapi-serializer**. Throughout, I separate three things: **what the code actually does**, **what the docs/README claim**, and **my inference / transplant assessment**. Cadwyn is the closest working implementation of the same model the team is copying, so the goal is to mine concrete mechanics, not to admire the framework.

---

## Table of Contents

1. [TL;DR](#1-tldr)
2. [The version-change / migration unit (crown jewel)](#2-the-version-change--migration-unit-crown-jewel)
3. [Bidirectional transforms](#3-bidirectional-transforms)
4. [Version declaration & resolution](#4-version-declaration--resolution)
5. [Schema/contract generation](#5-schemacontract-generation)
6. [Non-representational & behavioral changes + side effects](#6-non-representational--behavioral-changes--side-effects)
7. [Data / dependency migrations](#7-data--dependency-migrations)
8. [Testing approach](#8-testing-approach)
9. [DX / ergonomics](#9-dx--ergonomics)
10. [Stated limitations, gotchas, anti-patterns, philosophy](#10-stated-limitations-gotchas-anti-patterns-philosophy)
11. [Borrow / Adapt / Skip table](#11-borrow--adapt--skip-table)
12. [Key files map + bibliography](#12-key-files-map--bibliography)

---

## 1. TL;DR

**Cadwyn's model in a nutshell.** Your business logic, DB models, and serializers only ever know about **one** version — `HEAD` (roughly "latest, plus any extra fields older versions still need"). Every breaking change is captured as an immutable, named, human-described **`VersionChange`** class that (a) *describes* how the schema/endpoints looked in the previous version, and (b) *carries the data transforms* that convert a request **up** from an old version to HEAD and a response **down** from HEAD to an old version. A `VersionBundle` is the ordered single-source-of-truth list of dated versions and their changes. At startup Cadwyn walks that chain to **auto-generate** an older Pydantic schema + FastAPI route set per version, entirely in memory. This is exactly the "operate on latest, apply a chain of migrations at the serialization seam" model, plus Stripe's never-publicly-documented **bidirectional** twist.

Cadwyn is really **two fused systems**, and the distinction is the single most important takeaway for a Ruby port:

- **System A — the data-migration pipeline.** Plain functions that mutate request/response **dicts** (bodies, headers, cookies, query params, status) between adjacent versions. This is fully portable to Ruby; it is essentially what the Ruby gem `keygen-sh/request_migrations` already does.
- **System B — the schema/route auto-generator.** Reflection over Pydantic's `FieldInfo`/metaclass and FastAPI's `Dependant` to synthesize old OpenAPI schemas and per-version validation from HEAD + instructions. This is Cadwyn's cleverest part and it is **not** portable — it depends on Pydantic being a declarative, introspectable, reconstructable schema object. Rails/jsonapi-serializer has no equivalent.

**Ideas most worth stealing (5–8):**

1. **The `VersionChange` unit itself**: a small, immutable, richly-*described* class that groups *related* breaking changes and co-locates the forward+backward transforms. Naming + description are treated as first-class client documentation.
2. **Bidirectional transforms at the dict/hash seam** — migrate the *serialized payload*, never the model. Requests go up, responses come down. (System A.)
3. **Single-source-of-truth version registry** (`VersionBundle`): the ordered list of versions *is* the config; version-changes are bound to exactly one version.
4. **Schema-keyed targeting over path-keyed targeting** — attach a transform to a *serializer/schema type*, not a URL, so every endpoint sharing that shape is covered automatically (Cadwyn recommends this and warns path-based is error-prone).
5. **`VersionChangeWithSideEffects` + `.is_applied`** — an explicit, greppable escape hatch for behavioral (non-representational) changes, instead of scattered `if api_version >= …` checks.
6. **Auto-generated changelog** from the version-change descriptions/instructions (`GET /changelog`).
7. **A manual migration entry point** (`migrate_response_body`) so webhooks/jobs/cron can produce a versioned payload outside the request cycle.
8. **The testing discipline**: keep one common suite on HEAD; when you cut a version, copy only the now-failing tests into a per-version folder and pin them to that version.

**Things that will NOT transplant to Ruby (3–5):**

1. **Runtime auto-generation of older schemas from HEAD + instructions** (System B). No Pydantic → no `FieldInfo`/`create_model`/metaclass reconstruction. The whole `schema(Model).field("x").had(...)` half of the DSL exists to feed this generator; in Ruby most of it has no job to do.
2. **Automatic per-version OpenAPI + per-version request validation.** Cadwyn validates the request against the *old* schema, migrates, then re-validates against HEAD. Rails has no per-version schema to validate against unless you hand-write it.
3. **The double-validation / dependency re-execution machinery** and its `current_dependency_solver` workaround — an artifact of re-running FastAPI's dependency solver.
4. **Route cloning via `deepcopy` of FastAPI `APIRoute`/`Dependant` objects** — Rails routing is not a graph of introspectable route objects you reshape per version.

---

## 2. The version-change / migration unit (crown jewel)

### 2.1 The class

A breaking change is a subclass of `VersionChange` (`cadwyn/structure/versions.py:119-239`). It is a **declarative class used as a namespace** — never instantiated (the constructor raises, `versions.py:236-239`) and never subclassed further (`_check_no_subclassing`, `versions.py:229-234`). Its shape:

```python
class RemoveTaxIdEndpoints(VersionChange):
    description = "Remove 'GET /v1/tax_ids' and 'POST /v1/tax_ids' endpoints"
    instructions_to_migrate_to_previous_version = (
        endpoint("/v1/tax_ids", ["GET", "POST"]).existed,
    )
```

(`docs/concepts/version_changes.md:16-27`.)

Two class attributes are **required** and validated at class-creation time in `__init_subclass__` → `_validate_subclass` (`versions.py:136-227`):

- `description: str` — must be set or `CadwynStructureError` (`versions.py:186-191`). The docs are emphatic that this is *client-facing documentation*, "the **name** and the **summary** of the version change for your clients … grammatically correct, detailed, specific, and written for humans" (`version_changes.md:105-123`), and hold up Stripe's changelog prose as the model.
- `instructions_to_migrate_to_previous_version: Sequence` — the ordered list of *schema/endpoint/enum* instructions describing how the previous version looked (`versions.py:192-205`).

`__init_subclass__` also **sorts** the flat instruction list into typed buckets (`alter_schema_instructions`, `alter_enum_instructions`, `alter_endpoint_instructions`, `versions.py:163-184`) and scoops the request/response converter methods off the class body into per-schema and per-path dicts (`_extract_body_instructions_into_correct_containers`, `versions.py:149-161`). A guard rejects any stray attribute on the class body that isn't a migration instruction or a known dunder (`versions.py:206-227`) — so the class is forced to stay a pure declaration of changes.

**Inference / Rails lens:** the shape maps cleanly to a Ruby class or module: `description` as a constant/method, a declarative list of instructions, and `up`/`down` transform blocks. The `__init_subclass__` bucket-sorting is just "parse my declarations into indexed structures at load time" — trivially reproducible with a Ruby DSL and a registry. The immutability framing ("migrations are effectively immutable — they describe the breaking changes that happened in the past", `version_changes.md:127`) is a cultural rule worth adopting verbatim.

### 2.2 The instruction DSL

Instructions are built by small factory functions, each returning frozen dataclasses (`@dataclass(**DATACLASS_SLOTS)`). The public entrypoints are `schema`, `endpoint`, `enum` (`cadwyn/structure/__init__.py:1-31`).

**Schema/field instructions** (`cadwyn/structure/schemas.py`), entered via `schema(Model)`:

| DSL | Meaning | Cite |
|---|---|---|
| `schema(M).field("x").had(name=…, type=…, default=…, description=…, gt=…, …)` | field had a different name/type/attribute in the older version | `schemas.py:142-230` (huge kwarg list mirroring every Pydantic `FieldInfo` attribute, `PossibleFieldAttributes` `schemas.py:24-62`) |
| `schema(M).field("x").didnt_have("default", …)` | field lacked these attributes in the older version | `schemas.py:232-240` |
| `schema(M).field("x").didnt_exist` | field did not exist in the older version | `schemas.py:242-244` |
| `schema(M).field("x").existed_as(type=…, info=Field(...))` | field existed only in the older version | `schemas.py:246-255` |
| `schema(M).validator(fn).existed` / `.didnt_exist` | a Pydantic validator existed/didn't in the older version | `schemas.py:282-335` |
| `schema(M).had(name="Old")` | the schema was named differently (renames it in OpenAPI) | `schemas.py:337-338` |

**Endpoint instructions** (`cadwyn/structure/endpoints.py`), via `endpoint(path, methods, func_name=…)`:

| DSL | Meaning | Cite |
|---|---|---|
| `endpoint(p, m).existed` | endpoint existed in older versions (un-delete it) | `endpoints.py:95-102` |
| `endpoint(p, m).didnt_exist` | endpoint didn't exist in older versions | `endpoints.py:86-93` |
| `endpoint(p, m).had(path=…, description=…, status_code=…, tags=…, deprecated=…, dependencies=…, …)` | endpoint attribute differed in older versions | `endpoints.py:104-151` |

**Enum instructions** (`cadwyn/structure/enums.py`), via `enum(E)`: `.had(member=value, …)` and `.didnt_have("member", …)` (`enums.py:23-39`).

**Observation:** the DSL is deliberately *retrospective and declarative* — every verb is past tense (`had`, `didnt_have`, `existed`, `didnt_exist`). You describe how the world *looked*, not imperative steps. This is the "maintain the present, describe the past" mental model made concrete (`version_changes.md:125-137`).

### 2.3 A representative real example (from the runnable docs)

`docs_src/quickstart/tutorial/block003.py:44-61` is the canonical end-to-end example — one version change that turns a single `address` into a list `addresses`:

```python
class ChangeAddressToList(VersionChange):
    description = "Give user the ability to have multiple addresses at the same time"
    instructions_to_migrate_to_previous_version = (
        schema(UserCreateRequest).field("addresses").had(name="address", type=str),
        schema(UserResource).field("addresses").had(name="address", type=str),
    )

    @convert_request_to_next_version_for(UserCreateRequest)
    def change_address_to_multiple_items(request: RequestInfo):
        request.body["addresses"] = [request.body.pop("address")]

    @convert_response_to_previous_version_for(UserResource)
    def change_addresses_to_single_item(response: ResponseInfo) -> None:
        response.body["address"] = response.body.pop("addresses")[0]
```

This shows all three parts in one place: the **schema description** (feeds the auto-generator, System B), the **request-up transform**, and the **response-down transform** (both System A). The transforms operate on a **plain dict** (`request.body`, `response.body`), which is the part that ports directly to Ruby.

**Rails lens on the crown jewel:** the borrowable unit is *(1) a named class with a client-facing description, (2) a declaration of which serializer/attribute/endpoint changed, (3) an `up` block on the request hash, (4) a `down` block on the response hash.* Parts (1), (3), (4) map 1:1. Part (2)'s **schema-description half** is the part that mostly evaporates in Ruby (see §5) — in Cadwyn it exists to regenerate old Pydantic models and validate against them; without a Pydantic-equivalent, the Ruby version either drops it, or repurposes it as pure metadata for changelog/OpenAPI generation.

---

## 3. Bidirectional transforms

### 3.1 How they are expressed

Two decorators, defined in `cadwyn/structure/data.py`:

- `@convert_request_to_next_version_for(Schema, *more_schemas, check_usage=True)` **or** `(path, methods)` (`data.py:124-164`). The transformer takes a single `RequestInfo` and mutates it in place; the signature is enforced to be exactly `(request)` (`data.py:81-86`).
- `@convert_response_to_previous_version_for(Schema, *more, migrate_http_errors=False, check_usage=True)` **or** `(path, methods, migrate_http_errors=False)` (`data.py:189-240`). Takes a single `ResponseInfo`.

`RequestInfo` exposes `body`, `headers` (mutable), `cookies`, `query_params`, and (7.x) `form` (`data.py:17-42`). `ResponseInfo` exposes `body`, `status_code` (read/write), `headers`, `set_cookie`, `delete_cookie` (`data.py:46-72`). So a migration can reshape far more than the body — it can rewrite headers, flip status codes, move cookies. (`version_changes.md:270-287`.)

**Schema-keyed vs path-keyed targeting.** A converter can be bound to a **schema type** (applies to every route whose request body / `response_model` is that schema — or a shared parent schema, see `version_changes.md:203`) or to a **path + methods** pair. The docs strongly recommend schema-keyed: *"I highly recommend sticking to schemas, since it is much easier to introduce inconsistencies when using paths. For example, if you have ten endpoints sharing the same response body schema, you might forget to add migrations for 3 of them"* (`version_changes.md:242`). There is also a `check_usage=True` guard (`data.py:100`) that errors at startup if a schema-keyed converter matches no endpoint, unless you opt out with `check_usage=False` (`docs/how_to/change_openapi_schemas/change_schema_without_endpoint.md:11-17`).

### 3.2 Direction and ordering when resolving a request

The ordering is the mechanically important bit for the team. From the code:

- **Requests migrate UP** (requested version → HEAD). `VersionBundle._migrate_request` (`versions.py:406-454`) finds the requested version's index in `reversed_version_values` and iterates `self.reversed_versions[start + 1:]` — i.e. from the version just newer than the request, forward to HEAD — applying each version-change's request converters that match the body type or route (`versions.py:420-429`).
- **Responses migrate DOWN** (HEAD → requested version). `_migrate_response` (`versions.py:456-480`) computes `end = self.version_values.index(current_version)` and iterates `self.versions[:end]` — the versions newer than the request, newest-first — applying matching response converters (`versions.py:464-476`).

So a request entering at v1 with three later versions gets each intervening version's request-converter applied in order until it is shaped like HEAD; the HEAD response is then walked back down through each intervening version's response-converter until it matches v1. Within a single version, converters run in the order the instructions/methods were declared.

**Error migration.** Response converters skip 4xx/5xx bodies *unless* `migrate_http_errors=True` (`versions.py:477-479`, `data.py:172-186`). This lets you, e.g., turn a HEAD `400` back into the `404` an old version promised (`version_changes.md:244-268`).

**Full request lifecycle (from code, `versions.py:679-739` + `_migrate_request`):** validate incoming body against the **old** version's generated schema → `model_dump(by_alias=True, exclude_unset=True)` to a dict (`versions.py:717`) → run request converters up to HEAD → re-solve/validate against HEAD via FastAPI's `solve_dependencies` (`versions.py:442-453`); a failure here raises `CadwynHeadRequestValidationError`. Response path: run endpoint on HEAD → serialize model to dict (`_prepare_response_content`, `versions.py:64-102`) → run response converters down to the requested version → re-encode (`versions.py:551-677`).

### 3.3 Contrast with Stripe's public model

Stripe's publicly-described model is **response-only**: requests are accepted in the newest shape and only responses are transformed backward. Cadwyn adds the **request-up** half so that a client can also *send* an old-shaped request and have it upgraded to HEAD before business logic sees it. That symmetry is the feature the team called out as under-documented in Stripe. The cost is the double-validation and the "data versioning" hazard (a request converter that loses information — see the multi-address example, `version_changes.md:289-356`).

**Rails lens:** this whole section is System A and ports directly. `RequestInfo`/`ResponseInfo` become thin wrappers over the Rack request params hash and the serialized response hash. The up/down ordering is a simple ordered walk over your version registry — no Python machinery involved. The one thing to copy carefully is the **direction discipline** and the **"applied in declaration order within a version"** rule, and the decision to run transforms on the **already-serialized hash** rather than on ActiveRecord objects (matches Cadwyn dumping to a dict first, `versions.py:717`, `64-102`).

---

## 4. Version declaration & resolution

### 4.1 Declaring versions

Three primitives (`cadwyn/structure/versions.py`):

- `Version(value, *changes)` — a dated (or arbitrary-string) version and the version-changes that *created* it (`versions.py:265-277`). A `date` is normalized to ISO string.
- `HeadVersion(*changes)` — the special internal version; it may carry *schema-only* changes but **rejects** any request/response data migration (`versions.py:283-299`). This is used for the "make a field wider in HEAD than in latest" trick (§7).
- `VersionBundle(latest_or_head, *others, api_version_var=…)` — the single source of truth (`versions.py:311-363`).

Key invariants enforced at construction:

- The **earliest** version cannot have version-changes (`versions.py:358-363`) — "How could it have breaking changes if there were no prior versions?" (`version_changes.md:67`).
- A version-change may be bound to **exactly one** version (`versions.py:348-354`).
- Duplicate version values are rejected (`versions.py:340-347`).
- For **date** format, versions must be listed in **descending** order or `CadwynStructureError` (`applications.py:289-294`).

So a bundle looks like (`version_changes.md:60-64`):

```python
versions = VersionBundle(
    HeadVersion(),
    Version("2023-02-10", RemoveTaxIdEndpoints),
    Version("2022-11-16"),
)
```

### 4.2 Resolving the requested version per request

Handled in middleware, not per-route (`cadwyn/middleware.py`). The `Cadwyn` app defaults (`applications.py:90-93`): `api_version_location="custom_header"`, `api_version_parameter_name="x-api-version"`, `api_version_format="date"`, `api_version_default_value=None`.

- **Header location:** `HeaderVersionManager.get` reads the named header (`middleware.py:30-39`).
- **Path location:** `URLVersionManager.get` matches the version out of the URL path via a regex built from the known version set (`middleware.py:41-52`).
- `VersionPickingMiddleware.dispatch` (`middleware.py:107-131`): pulls the version; if absent, falls back to `api_version_default_value` (which may be a callable, e.g. per-tenant default); stores it in a `ContextVar` (`api_version_var`); and **echoes the matched version back** in the response header (`middleware.py:126-129`).
- **Waterfalling (date only):** if the requested date doesn't match exactly, the request routes to the *closest earlier* version, never a newer one (`docs/concepts/api_version_parameter.md:85-93`; the closest-lesser lookup is `versions.py:400-404`). The docs justify this from a microservice-fleet history (`api_version_parameter.md:87-93`). Note the code comment in `middleware.py:1-2` that waterfalling can simply be dropped for arbitrary-string versions since they aren't sortable.

### 4.3 Routing to versioned endpoints

At first request the app lazily generates one FastAPI router **per version** (`_cadwyn_initialize`, `applications.py:296-321`) via `generate_versioned_routers`, and stores them in `router.versioned_routers[version]`. Cadwyn thus adds a *version-selection layer above FastAPI's own routing* (`api_version_parameter.md:1-3`): middleware picks the version, then that version's router resolves the path. OpenAPI is served per version at `/openapi.json?version=…` and a docs dashboard lists all versions (`applications.py:390-434`, `491-502`).

**Rails lens:** version resolution ports directly — a Rack middleware or `before_action` that reads a header (default `X-API-VERSION`), applies a per-tenant/default fallback, stores it in a request-local, and echoes the resolved version back. Waterfalling ("round the requested date down to the nearest defined version") is a nice, cheap feature for date-based schemes and worth copying. The **per-version router generation** does not port; in Rails you have a single set of routes/controllers and select the transform chain by resolved version, rather than building N route tables. The declarative `VersionBundle` (ordered list + which changes belong to which version + descending-sort + "first version has no changes" invariants) is a clean spec to reimplement as a Ruby registry object.

---

## 5. Schema/contract generation

This is System B — Cadwyn's most impressive and **least portable** machinery. Findings here are from a focused read of `cadwyn/schema_generation.py` and `cadwyn/route_generation.py`.

### 5.1 What it does

At startup Cadwyn generates, **in memory, at runtime** (no `.py` files written), one full set of older Pydantic models + FastAPI routes per version, by walking HEAD through the version-change chain in reverse:

- Orchestrator `generate_versioned_models` (`schema_generation.py:808-822`, memoized with `@cache`) wraps every HEAD schema/enum into mutable wrappers (`_ModelBundle` of `_PydanticModelWrapper`/`_EnumWrapper`, `schema_generation.py:166-169`, built by reflecting `model.model_fields`, `__annotations__`, validators and `model_config`, `:266-330`).
- It applies HEAD-only changes once, then iterates versions, and **before** applying each version's changes it snapshots the current mutable bundle: `version_to_context_map[str(version.value)] = SchemaGenerator(copy.deepcopy(models))` (`:816-820`). Each version's `SchemaGenerator` therefore captures the model state *after all newer changes but before its own*.
- The concrete `{head_class: generated_model}` map is `SchemaGenerator.concrete_models`, materialized in `__init__` (`:754-761`) and looked up via `__getitem__` (`:763-778`).
- Materialization actually **calls Pydantic's metaclass**: `type(self.cls)(self.name, bases, namespace_dict, __pydantic_generic_metadata__=…)` (`generate_model_copy`, `:409-440`), and rebuilds each field with `pydantic.Field(**…)` (`:152-155`). The field/validator instructions from §2.2 are applied by mutating the wrappers in `_apply_alter_schema_instructions` (`:846-889`) — e.g. `FieldHadInstruction` → `_change_field_in_model` → `field.update_attribute(...)` (`:962-1041`), `FieldDidntExistInstruction` → `_delete_field_from_model` (`:1072-1101`).

Route generation (`route_generation.py:73-85`) deep-copies each route (`copy_route`, `:112-152`, with a pre-seeded `deepcopy` memo so `Dependant`/`body_field`/`response_model` aren't recursed into), then per version swaps in the versioned schemas via `migrate_route_to_version` (`schema_generation.py:530-544`): it reassigns `route.response_model`, rebuilds the response field with `fastapi.utils.create_model_field(...)`, rewrites the endpoint's `__annotations__`, and rebuilds FastAPI's `Dependant`. The type substitution bottoms out at `return self.generator[annotation]` (`:602-606`) — i.e. "replace this HEAD type with its versioned concrete model."

### 5.2 What it buys, and its cost

**Buys:** a genuine single source of truth. You maintain only HEAD schemas; every older OpenAPI document, every older validation model, and every older route is derived. Non-breaking additions automatically appear in all versions.

**Cost / limits (from the code and docs):**

- Heavy dependence on Pydantic/FastAPI internals — enumerated below.
- The `cadwyn render` CLI that prints the generated models as source is explicitly *"not yet ready for production code generation … doesn't handle schema renaming in a class's `__bases__`"* (`docs/concepts/schema_generation.md:9-10`). So the generated schemas are trustworthy at runtime but not fully round-trippable to source.
- Correctness leans on Pydantic re-validating, which forces the double-validation model and its costs (§3.2, §10).

### 5.3 Honest transplant assessment (Ruby / jsonapi-serializer)

**An equivalent is not feasible in Ruby without something Pydantic-shaped, and I would not attempt it.** The generator relies on a stack of Pydantic/FastAPI internals with no Ruby analogue, including:

- `model.model_fields`, `FieldInfo` (+ `__slots__`, `_attributes_set`, `metadata`), `pydantic.Field(**…)` reconstruction, `model_config`, `__pydantic_generic_metadata__`, construction through the Pydantic metaclass, and `PydanticUndefined` (`schema_generation.py:129,153,283-330,409-440,951`).
- The `__pydantic_decorators__` world for reconstructing validators/serializers (`schema_generation.py:30-38,97-105,273-280`), plus forward-ref evaluation via `pydantic._internal._typing_extra.try_eval_type` (`:1152-1157`).
- FastAPI's `route.dependant`, `body_field`, `response_field`, `fastapi.utils.create_model_field`, and route-tree APIs (`schema_generation.py:530-544`, `route_generation.py:16,171`).

jsonapi-serializer defines attributes with Ruby blocks and runtime `attribute :x { |obj| … }` calls — there is **no declarative, introspectable field-schema object you can programmatically diff and re-materialize** the way `model_fields` allows. The pragmatic Ruby analogue is therefore:

- **Keep per-version contracts hand-written** where they must exist (either per-version serializer classes, or a base serializer plus small per-version overrides), and rely on **System A transforms** to do the actual reshaping of the serialized hash. In other words: *don't* try to auto-generate old serializers; generate old *payloads* by transforming the HEAD payload.
- If you want per-version OpenAPI/JSON:API schema docs, generate them from a **separate declarative source** (or from the version-change *descriptions* used purely as metadata), not by reflecting on serializers.

Concretely: the `schema(Model).field("x").had(...)` half of Cadwyn's DSL is *the input to System B*. In a Rails port that keeps serializers hand-written, that half has little runtime work to do — keep it (if at all) only as **changelog/OpenAPI metadata**, and put your real effort into the request/response transforms.

---

## 6. Non-representational & behavioral changes + side effects

Cadwyn draws a hard line: *representational* changes (data reshapes) are done with transforms; *behavioral* changes are the exception and get a dedicated, greppable tool.

### 6.1 Endpoints that exist only in some versions

- **Delete in new, keep in old:** decorate the route `@router.only_exists_in_older_versions`, then in the version that removed it declare `endpoint(path, methods).existed` (`docs/concepts/endpoint_migrations.md:6-27`).
- **Add in new, absent in old:** define it normally, then `endpoint(path, methods).didnt_exist` in older versions (`endpoint_migrations.md:29-42`). Adding an endpoint is *not* breaking, so the recommended default is to add it everywhere and skip the migration (`docs/how_to/change_endpoints/index.md:3-5`).
- **Endpoint attribute changes** (path/description/status/tags/deprecated): `endpoint(...).had(...)` (`endpoint_migrations.md:44-59`).
- **Duplicate-function gotcha:** if two handlers share a path (e.g. old header-based vs new param-based), you must disambiguate with `func_name=` on the instruction or Cadwyn errors (`endpoint_migrations.md:69-120`).

### 6.2 Enum changes

`enum(E).had(member=value)` / `.didnt_have("member")` (`concepts/enum_migrations.md`). The docs note adding an enum member **can** be breaking (unlike adding an optional field), because clients may switch on the set of values (`enum_migrations.md:6-9`). These affect only the generated OpenAPI schema + validation, not the migrated-to-HEAD data (`enum_migrations.md:1-3`).

### 6.3 Added-required-fields & changed defaults (the subtle cases)

Two documented patterns (`docs/how_to/change_openapi_schemas/add_field.md:20-120`):

- **New required field with a compatible old default:** remove the default from HEAD, add `schema(Req).field("country").had(default="USA")` for the old version, **and** add a request converter that injects the default — because of a Pydantic detail (see §10) the old-version default alone doesn't reach HEAD.
- **New required field with no old analogue:** make it **wider in HEAD than in latest** — nullable in HEAD, required in `latest`, nullable again in old versions — so old requests can be upgraded without a `ValidationError`. This is where a change is attached to `HeadVersion(...)` (e.g. `MakePhoneNonNullableInLatest` in `HeadVersion`, `AddPhoneToUser` in the dated version, `add_field.md:105-118`).

### 6.4 Behavioral changes / side effects

For "the *logic* changed, not the shape," Cadwyn provides `VersionChangeWithSideEffects` (`versions.py:242-262`). It exposes a class property `is_applied` that returns whether the current request's version is at/after the version that introduced the side effect (`versions.py:250-262`). Business logic then does:

```python
if UserAddressIsCheckedInExternalService.is_applied:
    check_user_address_exists_in_an_external_service(payload.address)
```

(`version_changes.md:453-476`.) The point is to make dangerous, version-leaking logic **explicit and greppable** rather than scattering `if api_version >= date(...)` checks (`version_changes.md:440-449`).

**The author's own strong warning** (`version_changes.md:478-482`): *"Side effects are a very powerful tool but they must be used with great caution … 90% of time, you will **not** need them … By introducing side effects, you leak versioning into your business logic … which makes your code significantly harder to maintain."* The how-to enumerates exactly when a transform is the *wrong* tool and a side effect is needed (`docs/how_to/change_business_logic/index.md`): unexpected/absent data modifications, missing side actions like webhooks, and introducing/removing errors. Changing an error's status/message, by contrast, *is* representational and should be a response migration with `migrate_http_errors=True` (`change_business_logic/index.md:20-24`).

**Rails lens:** this section ports well and answers the team's "when is a transform NOT the right tool" question directly. Adopt (a) `existed`/`didnt_exist`-style endpoint availability per version — in Rails this is a routing/`before_action` guard keyed on resolved version; (b) a `SideEffect.applied?(version)` helper as the single sanctioned way to branch business logic on version, plus a lint/grep rule against raw version comparisons; (c) the "make HEAD wider than latest" rule for added-required-fields; (d) the doctrine that behavioral changes are rare and expensive.

---

## 7. Data / dependency migrations

### 7.1 Migrating inbound/stored data across versions

Requests are migrated **up** to HEAD before business logic; the transform mutates the serialized body dict (`request.body["addresses"] = [request.body.pop("address")]`, `tutorial/block003.py:55-57`). Responses are migrated **down** from HEAD. Business logic and DB never know versioning exists (`version_changes.md:205`).

### 7.2 Internal representations (HEAD ⊋ latest)

The important concept for lossy changes (`version_changes.md:289-356`). When an older version carried *more* data than latest (e.g. a list of addresses vs a single address), a naive down/up transform loses data. Cadwyn's answer: **HEAD is an "internal representation" — latest plus the extra fields older versions still need**, analogous to a DB row that's a superset of any single API view. You keep storing the richer data and return it from business logic; latest's schema strips the extra field, older schemas expose it. Then the response side often needs **no** converter at all (`version_changes.md:333-356`). This is the same idea as the `HeadVersion`/wider-type pattern in §6.3.

### 7.3 Manual / out-of-band migrations

`VersionBundle.migrate_response_body(SchemaClass, latest_body={...}, version="2000-01-01")` runs a latest-shaped body through all response converters down to a target version and returns it wrapped in that version's model (`version_changes.md:358-371`; public API `migrate_response_body`, `cadwyn/__init__.py:7,42`). Intended for webhooks, workers, cronjobs that must emit a versioned payload outside the request cycle.

### 7.4 The Pydantic-default footgun

Because Cadwyn dumps the validated request with `exclude_unset=True` (`versions.py:717`), **defaults defined only on the old-version schema do not reach HEAD** — you must *also* set them in a request converter (`docs/concepts/schema_migrations.md:64-78`). This is called out as an unavoidable implementation detail. (Rails note: a hash-transform pipeline has the analogous hazard — decide explicitly whether "unset" vs "defaulted" is distinguishable in your serialized payload, and prefer transforms that inject values rather than relying on schema defaults.)

### 7.5 Dependency re-execution

Because Cadwyn validates the request twice (old schema, then HEAD after migration, `version_changes.md:415`), any FastAPI dependency runs **twice**. The escape hatch is a `current_dependency_solver` dependency that tells you whether you're in the "fastapi" (pre-migration) or "cadwyn" (post-migration) pass (`version_changes.md:413-436`; public API `current_dependency_solver`, `cadwyn/__init__.py:5`). This is a direct artifact of System B and is **not** something a Rails port would inherit — unless you deliberately re-run validations, you won't have a double-execution problem.

---

## 8. Testing approach

From a focused read of the tutorial and core test suites.

- **End-to-end per-version tests** spin up the full app and hit the *same* route through one `TestClient` per version, pinned by the version header, asserting the shape differs. `tests/tutorial/test_example.py:8-20` builds three fixtures each `TestClient(app, headers={"X-API-VERSION": "…"})`; `:23-32` / `:35-45` / `:48-61` assert the same endpoints return `address` (v2000) vs `addresses` (v2001) vs `default_address` + a new subresource (v2002). The core suite uses a `create_versioned_clients(...)` fixture returning `{version → client}` and indexes by version string (`tests/test_data_migrations.py:288-314`), reading the header name from `app.router.api_version_parameter_name` (`tests/conftest.py:130-133`).
- **Direct schema-generation unit tests** bypass HTTP: call `generate_versioned_models(...)`, then compare a generated model against a hand-declared `ExpectedSchema` with a structural `assert_models_are_equal` that strips volatile keys (`cls`, `title`, `ref`) and compares serialized Pydantic core schemas (`tests/conftest.py:157-191`; examples `tests/test_schema_generation/test_schema_field.py:44-52`, `:127-133`).
- **Migration-function unit path**: call `migrate_response_body(bundle, Schema, latest_body={...}, version=date(...))` and assert `.model_dump()`, plus that an out-of-range version raises `CadwynError` (`tests/versioning_styles/test_versioning_formats.py:19-48`).
- **Version passed as** header `X-API-VERSION` with a date value (docs routes use `?version=` query param instead, `tests/test_applications.py:89`).
- **Snapshots:** no external golden-file directory; the project uses `inline-snapshot` for a few OpenAPI/validation-error body assertions (`tests/test_router_generation.py:17,1191-1204`), but generated schemas are checked *structurally*, not against stored snapshots.

**The recommended maintainer workflow** (`docs/concepts/testing.md:28-35`): keep a common suite on HEAD; before cutting a version, apply the breaking change to HEAD and run the HEAD tests — *the failures are your broken contracts*; copy only those failing tests into a new per-version folder pinned to the old version; write the `VersionChange` that makes them pass again; then update the HEAD tests to the new contract.

**Rails lens:** this ports cleanly and is worth adopting wholesale. RSpec request specs, one context per version, each sending the version header and asserting the JSON:API payload shape; a small helper analogous to `create_versioned_clients`. The "run HEAD tests to discover broken contracts, then freeze the failing ones per version" loop is a genuinely good discipline for a hand-written-serializer world. The direct schema-equality tests are the System-B-specific part you won't reproduce; replace them with **payload-level** golden/example tests of `migrate_response_body`-equivalent output per version.

---

## 9. DX / ergonomics

**Elegant:**

- The `VersionChange` class reads like documentation: name + prose description + past-tense declarations + two small transform methods, all co-located (`tutorial/block003.py:44-61`).
- Schema-keyed targeting means one converter covers every endpoint sharing a shape (`version_changes.md:242`).
- The registry is one object (`VersionBundle`) and load-time validation catches whole classes of mistakes: undescribed change, first-version-with-changes, duplicate version, unsorted versions, double-binding, converter matching no endpoint (`versions.py:186-363`, `applications.py:289-294`, `data.py:100`).
- Auto-generated `GET /changelog` derived from the version-change descriptions/instructions, with `hidden()` to keep internal changes out of the public changelog (`cadwyn/changelogs.py:51-90`, `docs/concepts/changelogs.md`).
- A CLI to *render* what a schema looks like in a given version for eyeballing (`schema_generation.md:12-29`).

**Boilerplate-heavy / sharp edges:**

- The rename-a-field case requires **three** coordinated edits (schema instruction + request converter + response converter) even though they express one logical change (`version_changes.md:188-201`) — the schema half exists only to feed System B.
- The `FieldChanges` dataclass mirrors ~40 Pydantic field attributes by hand (`schemas.py:24-104`) — a maintenance tax specific to tracking Pydantic.
- The added-required-field dance (HEAD-wider-than-latest, two version-changes across `HeadVersion` and a dated version) is genuinely subtle (`add_field.md:64-120`).

**Workflow to add a breaking change** (synthesizing `methodology.md:14-18` + `testing.md`): (1) make the breaking change in HEAD schemas/logic; (2) run HEAD tests to find broken contracts; (3) write a `VersionChange` describing the old shape + up/down converters; (4) register it on the new version in the bundle; (5) copy failing tests into a per-version folder pinned to the old version; (6) update HEAD tests to the new contract.

**Rails lens:** the elegant parts (single registry, load-time validation, auto-changelog, one-class-per-change, schema-keyed transforms) are all cheap to reproduce and high-value. The boilerplate parts are mostly System-B tax you can *drop* — in a hand-written-serializer world, a rename is just an up-transform + down-transform, no third "schema instruction" needed unless you want changelog metadata.

---

## 10. Stated limitations, gotchas, anti-patterns, philosophy

### Philosophy (from `docs/theory/*`, README)

- **Positioning:** *"Production-ready community-driven modern Stripe-like API versioning in FastAPI"* (`README.md:3`); the intellectual lineage (Stripe, Intercom, Convoy, Keygen, LinkedIn) is named explicitly (`docs/theory/how_we_got_here.md:53-54`, `docs/theory/references.md:9-13`).
- **"Maintain the present, describe the past."** Business logic knows nothing about versioning; older versions are generated; compatibility lives in small independent version-change modules (`README.md:27`; the git-checkout metaphor, `version_changes.md:131-137`).
- **Methodology principles** (`docs/concepts/methodology.md:3-12`): version-changes are *independent, atomic* diffs; a new version exists *only* for breaking changes; versions have little/no effect on business logic; **versions must always be data-compatible with each other**; creating versions is avoided at all costs; backward-compatible features are backported to all versions.
- **The framework-design lens** (`docs/theory/how_to_build_versioning_framework.md`): judge a versioning framework by ease of *creating* a version (`:5-7`), *deleting* one (`:9-11`), *seeing diffs* (`:13-15`), *how much must be duplicated* (`:17-19`), and *how easily accidental data-versioning is detected* (`:21-23`). Central tension (`:19`): *"the less you duplicate, the greater the risk of breaking older versions."*

### Explicit anti-patterns / warnings

- **Data versioning is the cardinal sin.** *"You are not versioning your API, you are versioning your **data** … Avoid this at all costs — all your API versions must be compatible … Data versioning is not a result of a complicated use case, it is a result of **errors** when devising a new version"* (`docs/concepts/beware_of_data_versioning.md:1-9`). Reinforced in `how_to_build_versioning_framework.md:21-23` and `how_we_got_here.md:15,33`.
- **Against per-version controllers / inheritance between versions.** The "versioned controllers" approach is called *"likely the worst … due to its fake simplicity and actual complexity … the hardest to migrate from"* (`how_we_got_here.md:19-27`); new-routes-including-old-routes or new-logic-inheriting-old-logic makes deleting a version *"painful (often even dangerous)"* (`how_to_build_versioning_framework.md:11`).
- **"Too simple is a trap."** A prior experiment made adding versions so easy they added too many and *"it got hellishly hard to maintain or get rid of those versions"* (`how_to_build_versioning_framework.md:5-7`).
- **Side effects leak versioning into business logic** — use rarely (§6.4, `version_changes.md:478-482`).
- **Prefer schema-keyed over path-keyed converters** — paths invite silent omissions (`version_changes.md:242`).

### Concrete technical gotchas (from code + docs)

- **Pydantic `exclude_unset` defaults footgun** — old-version defaults don't reach HEAD; set them in a request converter (`schema_migrations.md:64-78`).
- **Double validation → dependency runs twice**; needs `current_dependency_solver` for non-idempotent deps (`version_changes.md:413-436`).
- **`pydantic.RootModel` instances are memoized** — a converter meant for one `RootModel[list[User]]` silently affects an identical alias; subclass them or use path-based targeting (`version_changes.md:377-411`).
- **`StreamingResponse` / `FileResponse` bodies are not migrated** — you get raw access to `ResponseInfo._response` and must handle it yourself (`versions.py:586-590`, `version_changes.md:373-375`).
- **`cadwyn render` is not production-grade code generation** (`schema_generation.md:9-10`).
- **Changing endpoint dependencies only affects initial validation**, since the endpoint always runs HEAD dependencies (`endpoint_migrations.md:63-67`).

**Rails lens:** the philosophy and anti-patterns transfer *entirely* and should anchor the team's design doc — especially "always keep all versions data-compatible," "a new version only for breaking changes," "backport non-breaking changes to all versions," and "behavioral branching is a smell." The technical gotchas that are Pydantic/FastAPI-specific (`exclude_unset`, double validation, `RootModel` memoization, dependency re-run) **do not apply** to a hash-transform Rails pipeline — which is a point in favor of System A being *simpler* in Ruby than in Cadwyn.

---

## 11. Borrow / Adapt / Skip table

| # | Cadwyn idea | Stance for Rails JSON:API Kit | One-line why |
|---|---|---|---|
| 1 | `VersionChange` as a named, described, immutable unit grouping related breaking changes | **Borrow** | Perfect fit as a Ruby class/DSL; description-as-client-docs is free documentation. |
| 2 | Bidirectional transforms on the serialized **hash** (request-up, response-down) | **Borrow** | This is System A; ports 1:1 and is the real crown jewel. |
| 3 | Direction/ordering: walk versions newest-first for responses, oldest-first for requests; apply in declaration order within a version | **Borrow** | Deterministic, simple ordered walk over the registry. |
| 4 | Schema/serializer-keyed transform targeting (with path-keyed as fallback) | **Adapt** | Key on serializer class or resource type, not URL; Cadwyn's own warning about path drift holds. |
| 5 | `VersionBundle` single-source registry + load-time invariants (descending sort, first-version-no-changes, one-binding, no-op-converter guard) | **Borrow** | Cheap to reproduce; catches whole classes of mistakes at boot. |
| 6 | Version resolution in middleware: header (`X-API-VERSION`) or path, per-tenant default, echo resolved version back | **Borrow** | Standard Rack middleware; echoing the matched version is a nice touch. |
| 7 | Date waterfalling (round requested date down to nearest defined version) | **Adapt** | Great for date schemes; make it opt-in and skip for arbitrary-string versions (as Cadwyn notes). |
| 8 | `VersionChangeWithSideEffects` + `.is_applied` for behavioral changes | **Borrow** | The sanctioned, greppable alternative to scattered `if version >= …`. |
| 9 | Endpoint availability per version (`existed`/`didnt_exist`) | **Adapt** | In Rails this is a routing/`before_action` guard keyed on resolved version, not route cloning. |
| 10 | "HEAD is an internal representation ⊋ latest"; make HEAD wider than latest for added-required-fields | **Borrow** (as doctrine) | Your AR model/serializer must carry enough data for all versions; encodes the added-field pattern. |
| 11 | `migrate_response_body`-style manual entry point | **Borrow** | Webhooks/jobs/cron need to emit versioned payloads outside the request cycle. |
| 12 | Auto-generated changelog + `hidden()` | **Adapt** | Generate from version-change descriptions used as metadata; valuable client-facing artifact. |
| 13 | Testing loop: common HEAD suite + copy failing tests into per-version folders pinned to old versions | **Borrow** | Discipline is language-agnostic and keeps old versions covered with minimal duplication. |
| 14 | Runtime auto-generation of older schemas from HEAD + `schema(...).field(...).had(...)` instructions (System B) | **Skip** | Depends on Pydantic `FieldInfo`/metaclass/`create_model`; no jsonapi-serializer analogue. |
| 15 | Automatic per-version OpenAPI + per-version request validation | **Skip / Adapt** | No per-version schema to validate against; if you need per-version docs, drive them from a separate declarative source. |
| 16 | Double-validation + `current_dependency_solver` + dependency re-execution | **Skip** | Pure System-B artifact; a hash pipeline has no double-validation problem. |
| 17 | Route cloning via `deepcopy` of FastAPI `APIRoute`/`Dependant` per version | **Skip** | Rails routing isn't an introspectable per-version route graph. |
| 18 | The ~40-attribute `FieldChanges` mirror of Pydantic field options | **Skip** | Exists only to feed System B; a rename in Ruby is just up+down transforms. |

---

## 12. Key files map + bibliography

**Reviewed version/commit:** Cadwyn **7.1.0**, commit `22241f2d9d92e36d0222fd2536effb43b06e3b6e` (2026-07-06).

**Files a maintainer should read first (in order):**

| File | Why |
|---|---|
| `cadwyn/structure/versions.py` | The heart: `VersionChange` (`:119-239`), `VersionChangeWithSideEffects` (`:242-262`), `Version`/`HeadVersion`/`VersionBundle` (`:265-363`), and the request-UP / response-DOWN engines `_migrate_request` (`:406-454`) / `_migrate_response` (`:456-480`). |
| `cadwyn/structure/data.py` | The bidirectional transform DSL: `RequestInfo`/`ResponseInfo` (`:17-73`), `convert_request_to_next_version_for` (`:124-164`), `convert_response_to_previous_version_for` (`:189-240`). This is System A — the portable part. |
| `cadwyn/structure/schemas.py` | The schema/field instruction DSL (`schema().field().had()/.didnt_have()/.didnt_exist/.existed_as()`, validators, rename). Input to System B. |
| `cadwyn/structure/endpoints.py`, `enums.py` | Endpoint availability/attribute instructions and enum member instructions. |
| `docs/concepts/version_changes.md` | The single best conceptual doc: bidirectional migrations, path vs schema targeting, HTTP-error migration, internal representations, side effects, and most gotchas — all with examples. |
| `docs_src/quickstart/tutorial/block003.py` | The canonical runnable example (address→addresses) showing all parts of one version change. |
| `cadwyn/schema_generation.py` | System B: runtime in-memory generation of older Pydantic models from HEAD + instructions (`generate_versioned_models` `:808-822`, `generate_model_copy` `:409-440`, instruction application `:846-889`). The non-portable core. |
| `cadwyn/route_generation.py` | Per-version route cloning + schema swapping (`generate_versioned_routers` `:73-85`, `copy_route` `:112-152`). |
| `cadwyn/middleware.py` | Version resolution (header/path managers `:30-52`, `VersionPickingMiddleware` `:107-131`). |
| `cadwyn/applications.py` | The `Cadwyn(FastAPI)` app: constructor knobs/defaults (`:79-294`), lazy per-version router generation (`_cadwyn_initialize` `:296-321`). |
| `cadwyn/changelogs.py` | Auto-changelog generation + `hidden()` (`:51-90`). |
| `docs/theory/how_we_got_here.md`, `how_to_build_versioning_framework.md`, `docs/concepts/methodology.md`, `beware_of_data_versioning.md` | The philosophy, the rejected alternatives, and the anti-patterns. |

**Directly relevant external references** (from Cadwyn's own `docs/theory/references.md`) — two are Ruby request-migration gems the team should study alongside this review:

- **`keygen-sh/request_migrations`** (Ruby) — `references.md:29`. The closest existing Ruby implementation of System A.
- **`phillbaker/gates`** (Ruby) — `references.md:28`.
- Stripe's "API versioning" blog post (`references.md:9`) and Intercom/Convoy/Keygen/LinkedIn writeups (`references.md:10-13`).

**Method note / confidence:** All source-line citations were read directly except the internal mechanics of `schema_generation.py` and `route_generation.py` (§5) and the test-suite structure (§8), which were gathered by focused sub-reads and cross-checked against the public API in `cadwyn/__init__.py` and the concept docs. Where a claim rests on docs rather than code (e.g. waterfalling rationale, testing workflow) it is attributed to the doc. The code and docs did not materially disagree; the one place to watch is that the docs describe the *intended* mental model ("validate old → migrate → validate HEAD") which the code implements literally in `versions.py:679-739` + `_migrate_request`/`_migrate_response`.
