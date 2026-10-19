import EmberObject from "@ember/object";
import { setOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import deprecated from "discourse/lib/deprecated";
import {
  applyContentPluginApiCallbacks,
  applyOnChangePluginApiCallbacks,
  contentCallbackSources,
  hasContentPluginApiCallbacks,
  hasOnChangePluginApiCallbacks,
  onChangeCallbackSources,
} from "discourse/select-kit/lib/plugin-api";
import SelectEngine, {
  SelectItem,
  SelectItemId,
  SelectUpdateScope,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/**
 * Compatibility bridge that lets legacy
 * `api.modifySelectKit(id).{prependContent,appendContent,replaceContent,onChange}`
 * extensions of a component keep firing after that component is re-implemented on the
 * ui-kit select engine.
 *
 * It reuses select-kit's own `applyContentPluginApiCallbacks` /
 * `applyOnChangePluginApiCallbacks`, which already implement the exact legacy
 * semantics — the three ordering stages (all prepends, then all appends, then
 * replace-wins). Matching is limited to the engine's single kind. We feed those
 * functions a facade shaped like the old component instance:
 *
 *   - `pluginApiIdentifiers` — a one-element array containing the engine's kind;
 *   - a live `element` and a resolvable owner (`getOwner(component)`), which content
 *     callbacks read to build their context (e.g. locating the composer);
 *   - `isDestroying` / `isDestroyed`, checked by callbacks after an await;
 *   - `value`, and `content`, the list entering the current content run;
 *   - a `selectKit` sub-object (`value` / `filter` / `close()` / `select()` /
 *     `triggerSearch()` / `set("isLoading", …)`), the surface old callbacks and injected
 *     action rows call.
 *
 * Exactly one facade is memoized per engine instance, so a callback's per-instance
 * state lookups (which key a `WeakMap` on the component) stay stable across renders.
 *
 * The bridge is deliberately not silent: each control reports a deprecation per
 * registering plugin or theme, naming the replacement transformer, so the extension's
 * author is nudged to migrate and the deprecation collector gets a real usage signal.
 * It is a migration aid, not a kept API.
 */

const CONTENT_DEPRECATION_ID = "discourse.select-kit.modify-select-kit-content";
const ON_CHANGE_DEPRECATION_ID =
  "discourse.select-kit.modify-select-kit-on-change";
const DEPRECATION_SINCE = "2026.7.0";

type CallbackKind = "content" | "onChange";

/** The plugin or theme a deprecation is attributed to, as `deprecated()` takes it. */
type CallbackSource = {
  type: string;
  name?: string;
  id?: number;
  path?: string;
};

/**
 * The `selectKit` surface old callbacks and injected action rows drive. It reflects
 * the engine's live state and routes actions back through the engine.
 */
interface LegacySelectKit {
  readonly value: SelectValue;
  readonly filter: string;
  readonly isLoading: boolean;
  close(): void;
  select(value: SelectItemId, item?: SelectItem): void;
  /** Starts a new query using the current filter; accepts no filter argument. */
  triggerSearch(): void;
  set(key: string, val: unknown): void;
}

// Facade per engine instance (requirement: stable per-instance facade).
const FACADES = new WeakMap<SelectEngine, LegacySelectKitComponent>();

/** The `kind:source` pairs each facade has already reported. */
const REPORTED = new WeakMap<LegacySelectKitComponent, Set<string>>();

function facadeFor(engine: SelectEngine): LegacySelectKitComponent {
  const existing = FACADES.get(engine);
  if (existing) {
    return existing;
  }

  const legacy = engine.legacyContext;
  const owner = legacy?.owner;
  const getElement = legacy?.getElement;
  const isDestroyed = legacy?.isDestroyed;

  const facade = LegacySelectKitComponent.create({
    engine,
    content: [],
    isLoading: false,
    __getElement: getElement,
    __isDestroyed: isDestroyed,
  });
  let loading: { scope: SelectUpdateScope; resolve: () => void } | undefined;

  // The `selectKit` surface old callbacks and injected action rows drive. It closes
  // over the engine so it reflects live state and routes actions through the engine's
  // controlled `onChange`.
  const selectKit: LegacySelectKit = {
    get value() {
      return engine.value;
    },
    get filter() {
      return engine.filter;
    },
    get isLoading() {
      return facade.isLoading;
    },
    close() {
      engine.requestClose();
    },
    // Old signature: `select(value, item)`. The engine selects by item, so synthesize a
    // minimal item from the value when the caller passes only an id. While `isLoading`
    // holds an update, the write goes through its scope, so a hand pick made meanwhile
    // wins and the late write is dropped.
    select(value, item) {
      const target = item ?? { id: value };
      if (loading) {
        loading.scope.select(target);
      } else {
        engine.select(target);
      }
    },
    triggerSearch() {
      engine.reload();
    },
    set(key, val) {
      facade.set(key, val);
      if (key === "isLoading") {
        if (val && !loading) {
          engine.update(
            (scope) =>
              new Promise<void>((resolve) => {
                loading = { scope, resolve };
              })
          );
        } else if (!val && loading) {
          loading.resolve();
          loading = undefined;
        }
      }
    },
  };
  facade.selectKit = selectKit;

  if (owner) {
    setOwner(facade, owner);
  }

  FACADES.set(engine, facade);
  return facade;
}

/**
 * The `EmberObject`-backed stand-in for the old select-kit component instance. It is an
 * `EmberObject` (not a plain object) because legacy callbacks use `.get()` / `.set()`
 * and expect `getOwner(component)` to resolve.
 */
class LegacySelectKitComponent extends EmberObject {
  // These are populated by `EmberObject.create()` / assigned imperatively, never by a
  // field initializer, so they are `declare`d (no runtime field is emitted that could
  // clobber the value `create` sets during construction).
  declare engine: SelectEngine;
  declare selectKit: LegacySelectKit;
  declare isLoading: boolean;

  /** The items entering the current legacy content run, after native content customizations. */
  declare content: SelectItem[];
  declare __getElement?: () => Element | null;
  declare __isDestroyed?: () => boolean;

  get value(): SelectValue {
    return this.engine.value;
  }

  get pluginApiIdentifiers(): string[] {
    return this.engine.kind ? [this.engine.kind] : [];
  }

  get element(): Element | null {
    return this.__getElement?.() ?? null;
  }

  get isDestroying(): boolean {
    return this.__isDestroyed?.() ?? false;
  }

  get isDestroyed(): boolean {
    return this.__isDestroyed?.() ?? false;
  }
}

/**
 * Wraps the `onSelect` of any row the bridge injected so the engine's
 * `activate(item)` — which calls `item.onSelect(control, item)` — instead invokes the
 * legacy callback with the `selectKit` facade as its first argument, matching the old
 * `item.onSelect(selectKit, item)` contract. The facade reads `select`'s first argument as
 * an id, not an item.
 */
function adaptInjectedRows(
  inputItems: SelectItem[],
  resultItems: SelectItem[],
  facade: LegacySelectKitComponent
): SelectItem[] {
  const original = new Set(inputItems);
  return resultItems.map((row) => {
    if (original.has(row) || typeof row?.onSelect !== "function") {
      return row;
    }
    // Injected by a legacy extension, so it was written for the facade, not the control.
    const legacyOnSelect = row.onSelect as unknown as (
      selectKit: LegacySelectKit,
      item: SelectItem
    ) => void;
    return {
      ...row,
      onSelect: (_control: unknown, item: SelectItem) =>
        legacyOnSelect(facade.selectKit, item),
    };
  });
}

/**
 * Reports each registering plugin or theme once per control and callback kind. Reported
 * after render, so a deprecation configured to raise never aborts a render midway.
 */
function report(
  facade: LegacySelectKitComponent,
  kind: CallbackKind,
  targetKind: string,
  sources: Map<string, CallbackSource | undefined>
): void {
  let reported = REPORTED.get(facade);
  if (!reported) {
    reported = new Set();
    REPORTED.set(facade, reported);
  }

  const replacement =
    'api.registerValueTransformer("select-customizations", …)';
  const message = `\`api.modifySelectKit("${targetKind}")\` extends a component now built on the ui-kit select engine. Migrate to \`${replacement}\`.`;
  const id =
    kind === "content" ? CONTENT_DEPRECATION_ID : ON_CHANGE_DEPRECATION_ID;

  for (const [key, source] of sources) {
    const mark = `${kind}:${key}`;
    if (reported.has(mark)) {
      continue;
    }
    reported.add(mark);
    schedule("afterRender", () =>
      deprecated(message, { id, since: DEPRECATION_SINCE, source })
    );
  }
}

/**
 * Applies legacy content callbacks (prepend / append / replace) to the engine's item
 * list, after native content customizations have run. Returns the list unchanged
 * when nothing is registered for the engine's kind.
 *
 * @param items - The items after native content customizations.
 * @returns The items with legacy callbacks applied.
 */
export function applyLegacySelectKitContent(
  engine: SelectEngine,
  items: SelectItem[]
): SelectItem[] {
  const kind = engine.kind;
  const targets = kind ? [kind] : [];
  if (!kind || !hasContentPluginApiCallbacks(targets)) {
    return items;
  }

  const facade = facadeFor(engine);
  facade.content = items;
  report(facade, "content", kind, contentCallbackSources(targets));
  const result: SelectItem[] = applyContentPluginApiCallbacks(items, facade);

  // A no-op run returns the same array reference; only adapt when it actually changed.
  if (result === items) {
    return items;
  }

  return adaptInjectedRows(items, result, facade);
}

/**
 * Runs legacy onChange callbacks after a selection change, reconstructing the old
 * `(component, value, items)` signature. A side effect only — it never alters the value.
 *
 * @param value - The next value (id or id array).
 * @param items - The resolved item(s), already matching the arity (a single item for
 *   single-select, an array for multi) — passed through as-is to preserve the legacy
 *   callback signature.
 */
export function applyLegacySelectKitOnChange(
  engine: SelectEngine,
  value: SelectValue,
  items: SelectItem | SelectItem[] | null
): void {
  const kind = engine.kind;
  const targets = kind ? [kind] : [];
  if (!kind || !hasOnChangePluginApiCallbacks(targets)) {
    return;
  }

  const facade = facadeFor(engine);
  report(facade, "onChange", kind, onChangeCallbackSources(targets));

  applyOnChangePluginApiCallbacks(value, items, facade);
}
