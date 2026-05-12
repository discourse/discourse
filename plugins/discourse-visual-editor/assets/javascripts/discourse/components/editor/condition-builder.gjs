// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { writeAt } from "../../lib/condition-tree";
import ConditionRow from "./condition-row";

/**
 * Visual condition builder for the inspector. Replaces the read-only
 * `<pre>{{conditionsJson}}</pre>` from Phase 1 with an editable tree.
 *
 * Reads the selected block's condition tree from `visualEditor.selectedBlockData`
 * and walks it as a flat list of rows. Edits push the whole new tree back
 * through `visualEditor.updateSelectedConditions` — the service treats
 * conditions as structural (they gate visibility), so each edit bumps
 * `isDirty` and re-walks the outline.
 */
export default class ConditionBuilder extends Component {
  @service visualEditor;
  @service blocks;

  /**
   * The condition tree currently attached to the selected block. Either
   * an array (implicit AND), an object (`{any}` / `{not}` / leaf), or
   * `null` for "no conditions".
   *
   * Reads through `selectedBlockConditions`, a live getter on the
   * editor service that re-resolves the entry on every read. Going
   * through the snapshot in `selectedBlockData.conditions` would go
   * stale immediately after our first commit (the entry reference
   * changes during `_publishStructuralChange`), and reassigning the
   * snapshot from the service would force the inspector's args form to
   * remount and double-register its FormKit fields.
   *
   * @returns {Array|Object|null}
   */
  @cached
  get tree() {
    return this.visualEditor.selectedBlockConditions;
  }

  /**
   * The list of registered condition types the user can pick when adding
   * a new leaf. Memoised by `@cached` — the condition registry is
   * frozen post-boot so a single read is enough.
   *
   * @returns {ReturnType<import("discourse/services/blocks").default["listConditionTypes"]>}
   */
  @cached
  get conditionTypes() {
    return this.blocks.listConditionTypes();
  }

  get hasTree() {
    return this.tree != null;
  }

  /**
   * Called by a row to commit an edit. The row hands us the full new
   * tree (computed via `writeAt` against the existing one) so the
   * builder can hand it straight to the service.
   *
   * @param {Array|Object|null} newTree
   */
  @action
  commit(newTree) {
    this.visualEditor.updateSelectedConditions(newTree);
  }

  /**
   * Convenience for child rows: build a new tree with `replacement`
   * substituted at `path` and commit it. Avoids exposing the path-
   * mutation primitive to every row.
   *
   * @param {Array<string|number>} path
   * @param {*} replacement - Pass `undefined` to remove the node.
   */
  @action
  writeAndCommit(path, replacement) {
    const next = writeAt(this.tree, path, replacement);
    this.commit(next ?? null);
  }

  /**
   * Top-level "Add condition" affordance shown when the tree is empty.
   * Seeds the tree with a single leaf of the picked type.
   *
   * @param {string} typeId
   */
  @action
  seedWithLeaf(typeId) {
    this.commit({ type: typeId });
  }

  /**
   * Top-level "Add combinator" affordance shown when the tree is empty.
   * Seeds with an empty AND (implicit array form).
   */
  @action
  seedWithAnd() {
    this.commit([]);
  }

  /**
   * Clears all conditions from the block (commits null).
   */
  @action
  clearAll() {
    this.commit(null);
  }

  <template>
    <div class="visual-editor-condition-builder">
      {{#if this.hasTree}}
        <ConditionRow
          @node={{this.tree}}
          @path={{(array)}}
          @conditionTypes={{this.conditionTypes}}
          @writeAndCommit={{this.writeAndCommit}}
          @isRoot={{true}}
        />{{! empty-array helper above keeps recursion's path semantics }}

        <div class="visual-editor-condition-builder__footer">
          <button
            type="button"
            class="btn btn-flat visual-editor-condition-builder__clear"
            {{on "click" this.clearAll}}
          >
            {{dIcon "trash-can"}}
            <span>{{i18n "visual_editor.inspector.conditions.clear_all"}}</span>
          </button>
        </div>
      {{else}}
        <div class="visual-editor-condition-builder__empty">
          <p class="visual-editor-condition-builder__hint">
            {{i18n "visual_editor.inspector.conditions.empty_hint"}}
          </p>
          <div class="visual-editor-condition-builder__type-grid">
            {{#each this.conditionTypes as |typeMeta|}}
              <button
                type="button"
                class="btn btn-default visual-editor-condition-builder__type-pick"
                title={{typeMeta.description}}
                {{on "click" (fn this.seedWithLeaf typeMeta.type)}}
              >
                {{typeMeta.displayName}}
              </button>
            {{/each}}
          </div>
          <button
            type="button"
            class="btn btn-flat visual-editor-condition-builder__seed-group"
            {{on "click" this.seedWithAnd}}
          >
            {{dIcon "plus"}}
            <span>{{i18n
                "visual_editor.inspector.conditions.start_combinator"
              }}</span>
          </button>
        </div>
      {{/if}}
    </div>
  </template>
}
