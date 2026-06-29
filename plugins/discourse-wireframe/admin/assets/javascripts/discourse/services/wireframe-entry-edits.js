// @ts-check
import Service, { service } from "@ember/service";
import { VALID_BLOCK_ID_PATTERN } from "discourse/lib/blocks/-internals/patterns";
import {
  detachComposite,
  replaceEntryConditions,
  replaceEntryContainerArgs,
  replaceEntryId,
  replaceEntryInPlace,
  wrapAsOutletRoot,
} from "../lib/mutate-layout";

/**
 * Owns the "edit the selected entry in place" structural commands — conditions,
 * id, container-args (placement), raw-JSON replacement, and composite detach.
 * Each is a single structural mutation of the selected block routed through the
 * engine's record/publish chokepoint, so they're undoable and keep the canvas,
 * outline, and dirty state in lockstep.
 *
 * A peer command service in the editor's acyclic dependency graph: it injects
 * the mutation/undo engine (records the change), the read-only layout query
 * layer (locating the selected entry), and the selection concern (which entry is
 * selected). It never reaches back up into the kernel; its consumers (the
 * inspector tabs, the condition tree, the toolbar) inject it directly.
 */
export default class WireframeEntryEditsService extends Service {
  @service wireframeEditEngine;
  @service wireframeLayoutQuery;
  @service wireframeSelection;

  /**
   * Detaches the selected composite: materialises its code-defined parts (with
   * current overrides) into explicit `children` and drops the override map, so
   * it becomes a plain container the author can restructure. Peels exactly one
   * layer — a composite child stays composed. Structural commit (undo/redo +
   * draft re-publish). Manual only; never automatic.
   *
   * @returns {boolean}
   */
  detachSelectedComposite() {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this.wireframeEditEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = detachComposite(layout, key);
        if (!result.changed) {
          return false;
        }
        this.wireframeEditEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Updates one field inside a `containerArgs` namespace bag of the selected
   * entry (e.g. `containerArgs.grid.column`). Placement edits are rarer than
   * typography edits, so this routes directly through `replaceEntryContainerArgs`
   * (structural commit) rather than the keystroke-debounced arg-edit pipeline.
   *
   * @param {string} namespace - The childArgs namespace key (e.g. "grid").
   * @param {string} name - The field name inside the namespace.
   * @param {*} value
   * @returns {boolean}
   */
  updateSelectedContainerArg(namespace, name, value) {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key || !namespace || !name) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this.wireframeEditEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = replaceEntryContainerArgs(
          layout,
          key,
          namespace,
          (current) => ({ ...current, [name]: value })
        );
        if (!result.changed) {
          return false;
        }
        this.wireframeEditEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Replaces the selected entry with a wholly new entry object. Used by the
   * inspector's Raw JSON tab — the author edits the entry's serialised form and
   * commits the parsed result.
   *
   * Routes through `publishStructuralChange` because changes can touch any field
   * (args / conditions / classNames / id), and the outline / canvas need to
   * refresh.
   *
   * @param {Object} parsed - The parsed JSON, already validated by the caller
   *   (`InspectorRawJson` rejects invalid JSON without calling us).
   * @returns {boolean}
   */
  replaceSelectedEntryRaw(parsed) {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    // The outlet root must stay a single `layout` block. If a raw edit changes
    // its block away from `layout`, re-wrap so the invariant holds — the edited
    // entry then becomes the root layout's child.
    const nextEntry = this.wireframeLayoutQuery.isOutletRoot(key)
      ? wrapAsOutletRoot([parsed])[0]
      : parsed;
    return this.wireframeEditEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = replaceEntryInPlace(layout, key, nextEntry);
        if (!result.changed) {
          return false;
        }
        this.wireframeEditEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Replaces the selected entry's conditions.
   *
   * Conditions affect *whether* a block renders, so this is a structural change
   * — routes through `publishStructuralChange` to keep `isDirty`,
   * `structuralVersion`, and the outline's row count in lockstep with the
   * canvas.
   *
   * NOTE: this commits purely through `publishStructuralChange` and never
   * touches the selection's `selectedBlockData` snapshot. That snapshot backs
   * the inspector's args form (`<InspectorForm>` reads
   * `selectedBlockData.argsSnapshot` as `<Form @data>`); replacing it would
   * force FormKit to remount and re-register its fields, hitting "name already
   * in use" duplicate-registration errors. Consumers needing the freshest
   * conditions tree read the live `selectedBlockConditions` getter instead,
   * which resolves the latest entry on every read.
   *
   * @param {Array|Object|null} newConditions
   * @returns {boolean} true on success, false when no block is selected or the
   *   selection isn't locatable in the live layout.
   */
  updateSelectedConditions(newConditions) {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return false;
    }
    return this.wireframeEditEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = replaceEntryConditions(layout, key, newConditions);
        if (!result.changed) {
          return false;
        }
        this.wireframeEditEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Sets the `id` property on the selected entry. Validates against
   * `VALID_BLOCK_ID_PATTERN` (lowercase letters / digits / hyphens, starting
   * with a letter — same shape as block names). Empty / null clears the property
   * entirely.
   *
   * Returns `{ ok, error }` so the caller (the inspector's metadata section) can
   * show inline validation feedback without poking the service for state.
   *
   * @param {string|null} nextId
   * @returns {{ok: boolean, error: string|null}}
   */
  updateSelectedEntryId(nextId) {
    const key = this.wireframeSelection.selectedBlockKey;
    if (!key) {
      return { ok: false, error: "no-selection" };
    }
    const trimmed = typeof nextId === "string" ? nextId.trim() : nextId;
    if (trimmed && !VALID_BLOCK_ID_PATTERN.test(trimmed)) {
      return { ok: false, error: "invalid-format" };
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
    if (!located) {
      return { ok: false, error: "not-found" };
    }
    const committed = this.wireframeEditEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = replaceEntryId(layout, key, trimmed || null);
        if (!result.changed) {
          return false;
        }
        this.wireframeEditEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
    return { ok: !!committed, error: null };
  }
}
