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
import { optionsFromLegacyRows } from "discourse/ui-kit/select/-internals/engine/legacy-rows";
import type SelectArgsView from "discourse/ui-kit/select/-internals/engine/select-args";
import type { SelectOption } from "discourse/ui-kit/select/-internals/engine/select-option";
import SelectEngine, {
  SelectId,
  SelectRecord,
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
 * replace-wins). Matching uses the engine's kind and compatibility aliases. We feed those
 * functions a facade shaped like the old component instance:
 *
 *   - `pluginApiIdentifiers` — the kind and legacy names, deduplicated;
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

/** TODO (select-kit-replacement-cleanup): Names targeted by the deprecated bridge only. */
export function legacySelectKitIdentifiers(engine: SelectEngine): string[] {
  return [
    ...new Set([...(engine.kind ? [engine.kind] : []), ...engine.legacyKinds]),
  ];
}

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
  select(value: SelectId, item?: SelectRecord): void;
  /** Starts a new query using the current filter; accepts no filter argument. */
  triggerSearch(): void;
  set(key: string, val: unknown): void;
}

// Facade per engine instance (requirement: stable per-instance facade).
const FACADES = new WeakMap<SelectEngine, LegacySelectKitComponent>();

/** The callback kind, registration name and source each facade has already reported. */
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
  declare content: SelectRecord[];
  declare __getElement?: () => Element | null;
  declare __isDestroyed?: () => boolean;

  get value(): SelectValue {
    return this.engine.value;
  }

  get pluginApiIdentifiers(): string[] {
    return legacySelectKitIdentifiers(this.engine);
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
 * Reports each registering plugin or theme once per control, registration name and callback kind. Reported
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
    const mark = `${kind}:${targetKind}:${key}`;
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
 * Applies legacy content callbacks (prepend / append / replace) to the engine's options, after
 * native content customizations have run. Callbacks see records, as select-kit content; what
 * they return maps back to options, and a row they injected is written for select-kit, so its
 * `onSelect` is called with the row as `this` and the `selectKit` facade, as select-kit did.
 * Returns the options unchanged when nothing is registered for the engine's kind or
 * compatibility aliases.
 *
 * @param options - The options after native content customizations.
 * @param args - The engine's args, for value keys.
 * @returns The options with legacy callbacks applied.
 */
export function applyLegacySelectKitContent(
  engine: SelectEngine,
  options: SelectOption[],
  args: SelectArgsView
): SelectOption[] {
  const targets = legacySelectKitIdentifiers(engine);
  if (!hasContentPluginApiCallbacks(targets)) {
    return options;
  }

  const records = options.map((option) => option.record);
  const facade = facadeFor(engine);
  facade.content = records;
  for (const target of targets) {
    report(facade, "content", target, contentCallbackSources([target]));
  }
  const result: SelectRecord[] = applyContentPluginApiCallbacks(
    records,
    facade,
    { bridgeOnly: true }
  );

  if (
    result.length === records.length &&
    result.every((record, index) => record === records[index])
  ) {
    return options;
  }

  return optionsFromLegacyRows(
    options,
    result,
    args,
    (legacy, row) => (_control, record) =>
      void legacy.call(row, facade.selectKit, record)
  );
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
  items: SelectRecord | SelectRecord[] | null
): void {
  const targets = legacySelectKitIdentifiers(engine);
  if (!hasOnChangePluginApiCallbacks(targets)) {
    return;
  }

  const facade = facadeFor(engine);
  for (const target of targets) {
    report(facade, "onChange", target, onChangeCallbackSources([target]));
  }

  applyOnChangePluginApiCallbacks(value, items, facade, { bridgeOnly: true });
}
