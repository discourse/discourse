// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  appendChild,
  classifyNode,
  emptyAnd,
  emptyLeaf,
  emptyNot,
  emptyOr,
} from "../../lib/condition-tree";
import ConditionLeafArgs from "./condition-leaf-args";

/**
 * One node in the condition tree. Renders recursively for combinators
 * (AND / OR / NOT) and delegates to `<ConditionLeafArgs>` for leaves.
 *
 * Edits are bubbled up via the `@writeAndCommit` callback passed in by
 * `<ConditionBuilder>`. Each row computes the absolute path of the
 * node-being-edited and lets the builder splice the change into the
 * tree.
 *
 * Args:
 *  - `@node` — the subtree this row renders.
 *  - `@path` — the absolute path from the root tree to this node.
 *  - `@conditionTypes` — discovery output from `blocks.listConditionTypes()`.
 *  - `@writeAndCommit(path, replacement)` — splice + commit, the row's
 *     only handle on the parent. Pass `undefined` for removal.
 *  - `@isRoot` — true at the top level; used to suppress the
 *     remove-self button there (the builder owns the clear-all action).
 */
export default class ConditionRow extends Component {
  /** Builds the absolute path of a child by appending one segment. */
  childPath = (segment) => [...this.args.path, segment];

  get kind() {
    return classifyNode(this.args.node);
  }

  get isCombinator() {
    return ["and", "or", "not"].includes(this.kind);
  }

  /**
   * The combinator's child nodes, normalised to an array of
   * `{node, segment}` pairs so the template can iterate uniformly.
   * For NOT, the single child sits at segment `"not"`; for AND/OR the
   * children sit at numeric indices.
   */
  get childEntries() {
    const node = this.args.node;
    if (Array.isArray(node)) {
      return node.map((child, i) => ({ node: child, segment: i }));
    }
    if (this.kind === "or") {
      return node.any.map((child, i) => ({ node: child, segment: i }));
    }
    if (this.kind === "not") {
      return [{ node: node.not, segment: "not" }];
    }
    return [];
  }

  /**
   * Computes the path to the OR's `any` array so `appendChild` can
   * splice into it. The path layer differs between AND (array directly)
   * and OR (array under the `any` key) so we centralise it here.
   */
  get combinatorListPath() {
    if (this.kind === "or") {
      return [...this.args.path, "any"];
    }
    return this.args.path;
  }

  @action
  changeLeafType(event) {
    const typeId = event.target.value;
    this.args.writeAndCommit(this.args.path, emptyLeaf(typeId));
  }

  @action
  appendLeaf(typeId) {
    // Build the new tree by appending into the right list path.
    // ConditionBuilder.writeAndCommit takes a *replacement at path*, not
    // an append, so we hand it the result of `appendChild` against the
    // combinator subtree and overwrite the combinator at its own path.
    const next = appendChild(this.args.node, [], emptyLeaf(typeId));
    this.args.writeAndCommit(this.args.path, next);
  }

  @action
  appendCombinator(kind) {
    const child =
      kind === "and" ? emptyAnd() : kind === "or" ? emptyOr() : emptyNot();
    const next = appendChild(this.args.node, [], child);
    this.args.writeAndCommit(this.args.path, next);
  }

  @action
  removeSelf() {
    this.args.writeAndCommit(this.args.path, undefined);
  }

  /**
   * Wraps the "Add ▼" select so picking a type appends a fresh leaf
   * and resets the select back to its placeholder slot.
   */
  @action
  handleAddLeafSelect(event) {
    const typeId = event.target.value;
    if (!typeId) {
      return;
    }
    this.appendLeaf(typeId);
    event.target.value = "";
  }

  @action
  onLeafArgChange(argName, value) {
    const current = this.args.node ?? {};
    const next = { ...current, [argName]: value };
    this.args.writeAndCommit(this.args.path, next);
  }

  /**
   * Resolves the typeMeta from the discovery list for the current leaf.
   * Returns null when the type isn't registered — keeps the row
   * survivable for typos / unregistered conditions in legacy data.
   */
  get leafTypeMeta() {
    if (this.kind !== "leaf") {
      return null;
    }
    return (
      this.args.conditionTypes.find((c) => c.type === this.args.node.type) ??
      null
    );
  }

  <template>
    <div
      class={{dConcatClass
        "visual-editor-condition-row"
        (concat "--" this.kind)
      }}
    >
      {{#if this.isCombinator}}
        <div class="visual-editor-condition-row__header">
          <span class="visual-editor-condition-row__kind">
            {{#if (eq this.kind "and")}}
              {{i18n "visual_editor.inspector.conditions.combinator_and"}}
            {{else if (eq this.kind "or")}}
              {{i18n "visual_editor.inspector.conditions.combinator_or"}}
            {{else}}
              {{i18n "visual_editor.inspector.conditions.combinator_not"}}
            {{/if}}
          </span>

          {{#unless @isRoot}}
            <button
              type="button"
              class="btn btn-flat visual-editor-condition-row__remove"
              {{on "click" this.removeSelf}}
            >
              {{dIcon "xmark"}}
            </button>
          {{/unless}}
        </div>

        <div class="visual-editor-condition-row__children">
          {{#each this.childEntries as |child|}}
            <ConditionRow
              @node={{child.node}}
              @path={{this.childPath child.segment}}
              @conditionTypes={{@conditionTypes}}
              @writeAndCommit={{@writeAndCommit}}
              @isRoot={{false}}
            />
          {{/each}}

          {{#unless (eq this.kind "not")}}
            <div class="visual-editor-condition-row__add">
              <select
                aria-label={{i18n
                  "visual_editor.inspector.conditions.add_leaf"
                }}
                {{on "change" this.handleAddLeafSelect}}
              >
                <option value="">
                  {{i18n "visual_editor.inspector.conditions.add_leaf"}}
                </option>
                {{#each @conditionTypes as |t|}}
                  <option value={{t.type}}>{{t.displayName}}</option>
                {{/each}}
              </select>
              <button
                type="button"
                class="btn btn-flat"
                title={{i18n
                  "visual_editor.inspector.conditions.add_combinator_and"
                }}
                {{on "click" (fn this.appendCombinator "and")}}
              >
                {{i18n "visual_editor.inspector.conditions.combinator_and"}}
              </button>
              <button
                type="button"
                class="btn btn-flat"
                title={{i18n
                  "visual_editor.inspector.conditions.add_combinator_or"
                }}
                {{on "click" (fn this.appendCombinator "or")}}
              >
                {{i18n "visual_editor.inspector.conditions.combinator_or"}}
              </button>
              <button
                type="button"
                class="btn btn-flat"
                title={{i18n
                  "visual_editor.inspector.conditions.add_combinator_not"
                }}
                {{on "click" (fn this.appendCombinator "not")}}
              >
                {{i18n "visual_editor.inspector.conditions.combinator_not"}}
              </button>
            </div>
          {{/unless}}
        </div>
      {{else}}
        <div class="visual-editor-condition-row__leaf">
          <div class="visual-editor-condition-row__leaf-head">
            <select
              class="visual-editor-condition-row__type"
              {{on "change" this.changeLeafType}}
            >
              {{#each @conditionTypes as |t|}}
                <option value={{t.type}} selected={{eq t.type @node.type}}>
                  {{t.displayName}}
                </option>
              {{/each}}
            </select>

            {{#unless @isRoot}}
              <button
                type="button"
                class="btn btn-flat visual-editor-condition-row__remove"
                {{on "click" this.removeSelf}}
              >
                {{dIcon "xmark"}}
              </button>
            {{/unless}}
          </div>

          {{#if this.leafTypeMeta}}
            <ConditionLeafArgs
              @typeMeta={{this.leafTypeMeta}}
              @node={{@node}}
              @onChange={{this.onLeafArgChange}}
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
