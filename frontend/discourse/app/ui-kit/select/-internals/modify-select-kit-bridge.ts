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
 * replace-wins) and the fan-out across an identifier array (a callback on a base
 * identifier fires for every derived one). To preserve those semantics faithfully we
 * feed those functions a facade shaped like the old component instance:
 *
 *   - `pluginApiIdentifiers` — the identifier array the callbacks are keyed on;
 *   - a live `element` and a resolvable owner (`getOwner(component)`), which content
 *     callbacks read to build their context (e.g. locating the composer);
 *   - `isDestroying` / `isDestroyed`, checked by callbacks after an await;
 *   - a `selectKit` sub-object (`value` / `filter` / `close()` / `select()` /
 *     `set("isLoading", …)`), the surface old callbacks and injected action rows call.
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
    isLoading: false,
    __getElement: getElement,
    __isDestroyed: isDestroyed,
  });

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
    // minimal item from the value when the caller passes only an id.
    select(value, item) {
      engine.select(item ?? { id: value });
    },
    set(key, val) {
      facade.set(key, val);
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
  declare __getElement?: () => Element | null;
  declare __isDestroyed?: () => boolean;

  get pluginApiIdentifiers(): string[] {
    return this.engine.identifiers;
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
  identifiers: string[],
  sources: Map<string, CallbackSource | undefined>
): void {
  let reported = REPORTED.get(facade);
  if (!reported) {
    reported = new Set();
    REPORTED.set(facade, reported);
  }

  const replacement =
    kind === "content"
      ? 'api.registerValueTransformer("select-content", …)'
      : 'api.registerBehaviorTransformer("select-on-change", …)';
  const message = `\`api.modifySelectKit("${identifiers.join(
    '"/"'
  )}")\` extends a component now built on the ui-kit select engine. Migrate to \`${replacement}\`.`;
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
 * list, after the native `select-content` transformer has run. Returns the list
 * unchanged when nothing is registered for the engine's identifiers.
 *
 * @param items - The items after native transformers.
 * @returns The items with legacy callbacks applied.
 */
export function applyLegacySelectKitContent(
  engine: SelectEngine,
  items: SelectItem[]
): SelectItem[] {
  const identifiers = engine.identifiers;
  if (!identifiers.length || !hasContentPluginApiCallbacks(identifiers)) {
    return items;
  }

  const facade = facadeFor(engine);
  report(facade, "content", identifiers, contentCallbackSources(identifiers));
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
  const identifiers = engine.identifiers;
  if (!identifiers.length || !hasOnChangePluginApiCallbacks(identifiers)) {
    return;
  }

  const facade = facadeFor(engine);
  report(facade, "onChange", identifiers, onChangeCallbackSources(identifiers));

  applyOnChangePluginApiCallbacks(value, items, facade);
}
