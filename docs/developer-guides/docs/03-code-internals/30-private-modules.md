---
title: Private modules and the `-internals` convention
short_title: Private modules
id: private-modules
---

<div data-theme-toc="true"> </div>

## What `-internals` means

A folder named `-internals` holds code that is **not public API**. It may be renamed,
reshaped or deleted without notice, and nothing outside core should depend on it.

It is a signal about support, not a barrier. Nothing lints it, and internals are imported
across folder boundaries all the time: `lib/-internals/drag-and-drop` is consumed by ui-kit
modifiers and a service, and `lib/blocks/-internals` from well outside `lib/blocks/`.
Reaching into another module's `-internals` from core is allowed. What is not allowed is a
plugin or theme depending on any of it.

## Where it goes

Put `-internals` immediately inside the unit that **owns the concept**. Ownership decides
placement, not who imports it.

**One named owner.** A component or module owns the concept, so its internals sit inside it:

```
ui-kit/d-reorderable-list/-internals/     owned by DReorderableList
lib/blocks/-internals/                    owned by the blocks module
```

**No single owner.** Several members share the mechanism, so it goes in the `-internals` of the
smallest namespace that contains every consumer, under a folder named for the mechanism:

```
ui-kit/-internals/cursor/         consumed by dRovingFocus and DReorderableList,
                                  both ui-kit members
lib/-internals/drag-and-drop/     consumed by ui-kit modifiers and a service, so no
                                  namespace narrower than the app contains them
```

`lib/` is the app-wide root, which is why a mechanism whose consumers span several namespaces
lands there. Reach for it only when nothing narrower fits. A mechanism used only within
`ui-kit` belongs to `ui-kit`.

## Choosing

1. Does one component or module own the concept? Then `<owner>/-internals/`.
2. Otherwise, list every consumer and take the smallest namespace containing all of them. Then
   `<namespace>/-internals/<mechanism>/`.
3. If that namespace is the app itself, it is `lib/-internals/<mechanism>/`.

Do not nest `-internals` under a namespace-scoped `lib/`. A namespace `lib/` (as in
`form-kit/lib/`) holds flat, supported helpers; `-internals` already says the code is private,
so the extra level adds nothing.

## Splitting a shared mechanism out

When a second consumer appears for something living inside one owner's `-internals`, move the
shared part up rather than importing across. Keep the move behaviour-neutral and let the
existing suite prove it: `ItemScope` and the stepping helpers were lifted out of
`ui-kit/modifiers/d-roving-focus/` into `ui-kit/-internals/cursor/` this way, with
the modifier's own tests as the gate.

Leave the types with the code that uses them. A shared `types.ts` earns its place when several
files in the folder read from it, not when each type has a single consumer.
