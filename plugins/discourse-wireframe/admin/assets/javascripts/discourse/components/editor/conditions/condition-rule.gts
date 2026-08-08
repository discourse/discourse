import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { type ComponentLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ConditionLeafArgs from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/condition-leaf-args";
import OutletArgConditionEditor from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/outlet-arg-condition-editor";
import RouteConditionEditor from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/route-condition-editor";
import SettingConditionEditor from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/setting-condition-editor";
import UserConditionEditor from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/user-condition-editor";
import ViewportConditionEditor from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/viewport-condition-editor";
import { iconForConditionType } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-icons";
import { summarizeLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-summary";
import type {
  ConditionLeaf,
  ConditionTypeMeta,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

/**
 * The contract every per-type condition editor honors: it receives the
 * leaf being edited plus its registry entry, and bubbles a fully-formed
 * replacement leaf on each edit.
 */
interface ConditionEditorSignature {
  /** Condition leaf and replacement callback. */
  Args: {
    /** Condition leaf being edited. */
    leaf?: ConditionLeaf;
    /** Replaces the edited condition leaf. */
    onChange: (
      /** Updated condition leaf. */
      nextLeaf: ConditionLeaf
    ) => void;
  };
}
type ConditionEditorComponent = ComponentLike<ConditionEditorSignature>;

interface ConditionRuleSignature {
  /** Rule state and mutation callbacks. */
  Args: {
    /** Condition leaf rendered by this row. */
    node?: ConditionLeaf;
    /** Registry descriptor for the condition type. */
    typeMeta: ConditionTypeMeta;
    /** Registered condition descriptors available for type changes. */
    conditionTypes: ConditionTypeMeta[];
    /** Replaces the condition leaf. */
    onUpdate: (
      /** Updated condition leaf. */
      nextLeaf: ConditionLeaf
    ) => void;
    /** Changes the condition type. */
    onChangeType: (
      /** Replacement condition type identifier. */
      typeId: string
    ) => void;
    /** Removes the condition leaf. */
    onRemove: () => void;
    /** Whether the rule starts expanded. */
    startExpanded?: boolean;
  };
}

/**
 * One leaf row in the conditions tree. Renders a compact summary line
 * that expands in-place to reveal the per-type editor — no popover,
 * so the body grows the column rather than fighting z-index. The row
 * is a self-toggling disclosure: clicking the header (icon / label /
 * summary / chevron) flips `expanded` and reveals the inline editor.
 *
 * Args:
 *  - `@node` — the leaf condition (`{type, ...args}`).
 *  - `@typeMeta` — registry entry for the leaf's type. When unknown,
 *     the parent passes a stub.
 *  - `@conditionTypes` — registry list, used by the type-switch
 *     dropdown inside the editor body.
 *  - `@onUpdate(nextLeaf)` — bubble an arg edit up. The parent
 *     converts this into a tree-level write.
 *  - `@onChangeType(typeId)` — switch the leaf's type. Resets the
 *     args because they're type-specific.
 *  - `@onRemove()` — delete this leaf from its containing group.
 *  - `@startExpanded` — when true, the row mounts in the expanded
 *     state. The parent sets this for freshly-added rules so the
 *     author immediately sees the editor.
 */
export default class ConditionRule extends Component<ConditionRuleSignature> {
  /** Whether the rule's editor is visible. */
  @tracked expanded: boolean;

  /**
   * Checks whether a condition type is selected.
   *
   * @param typeId - Registered condition type identifier.
   * @returns Whether the condition type is selected.
   */
  isTypeSelected: (typeId: string) => boolean = (typeId) =>
    this.args.node?.type === typeId;

  /**
   * Creates a condition rule.
   *
   * @param owner - Ember owner for the component instance.
   * @param args - Rule arguments supplied by the parent group.
   */
  constructor(owner: Owner, args: ConditionRuleSignature["Args"]) {
    super(owner, args);
    this.expanded = this.args.startExpanded ?? false;
  }

  /**
   * Icon ID representing the rule's condition type. Drives the visual
   * anchor next to each rule row.
   */
  get icon(): string {
    return iconForConditionType(this.args.node?.type);
  }

  /**
   * Short, human-readable summary of the leaf's current configuration
   * (e.g. "Logged-in users in @staff"). Shown collapsed in the rule
   * header so authors can scan rules without expanding them.
   */
  get summary(): string {
    return summarizeLeaf(this.args.node);
  }

  /**
   * Picks the bespoke editor component for the leaf's type. All five
   * built-in types have a dedicated editor; anything else falls back
   * to the generic `<ConditionLeafArgs>` so unregistered conditions
   * still get *some* editing surface.
   */
  get editorComponent(): ConditionEditorComponent | null {
    switch (this.args.node?.type) {
      case "user":
        return UserConditionEditor;
      case "viewport":
        return ViewportConditionEditor;
      case "route":
        return RouteConditionEditor;
      case "setting":
        return SettingConditionEditor;
      case "outlet-arg":
        return OutletArgConditionEditor;
      default:
        return null;
    }
  }

  /** Toggles the inline condition editor. */
  @action
  toggleExpanded(): void {
    this.expanded = !this.expanded;
  }

  /**
   * Replaces one generic condition argument.
   *
   * @param name - Argument name to update.
   * @param value - Replacement argument value.
   */
  @action
  onArgChange(name: string, value: unknown): void {
    const next: ConditionLeaf = { ...this.args.node, [name]: value };
    if (value === undefined) {
      delete next[name];
    }
    this.args.onUpdate(next);
  }

  /**
   * Replaces the entire condition leaf.
   *
   * @param nextLeaf - Replacement condition leaf.
   */
  @action
  onLeafChange(nextLeaf: ConditionLeaf): void {
    this.args.onUpdate(nextLeaf);
  }

  /** Removes the condition leaf. */
  @action
  remove(): void {
    this.args.onRemove();
  }

  /**
   * Changes the condition type from the native selector.
   *
   * @param event - Condition-type selector event.
   */
  @action
  changeType(event: Event): void {
    if (!(event.currentTarget instanceof HTMLSelectElement)) {
      return;
    }
    const typeId = event.currentTarget.value;
    if (typeId) {
      this.args.onChangeType(typeId);
    }
  }

  <template>
    <div
      class={{dConcatClass
        "wireframe-condition-rule"
        (if this.expanded "--expanded")
      }}
    >
      <DButton
        class="wireframe-condition-rule__header"
        @ariaExpanded={{this.expanded}}
        @action={{this.toggleExpanded}}
      >
        <span class="wireframe-condition-rule__chevron">
          {{dIcon "chevron-right"}}
        </span>
        <span class="wireframe-condition-rule__icon" aria-hidden="true">{{dIcon
            this.icon
          }}</span>
        <span class="wireframe-condition-rule__label">
          {{@typeMeta.displayName}}
        </span>
        <span class="wireframe-condition-rule__sep" aria-hidden="true">
          —
        </span>
        <span class="wireframe-condition-rule__summary">
          {{this.summary}}
        </span>
      </DButton>

      {{! The remove button sits inside the row but outside the header
        disclosure button. It's a sibling at the DOM level (the header
        button doesn't wrap it), so it's not a nested-interactive even
        though the linter can't tell with this layout. }}
      <DButton
        class="wireframe-condition-rule__remove"
        @icon="xmark"
        @title="wireframe.inspector.conditions.remove_condition"
        @action={{this.remove}}
      />

      {{#if this.expanded}}
        <div class="wireframe-condition-rule__body">
          <label class="wireframe-condition-rule__type-row">
            <span>{{i18n "wireframe.inspector.conditions.type_label"}}</span>
            <select {{on "change" this.changeType}}>
              {{#each @conditionTypes as |typeMeta|}}
                <option
                  value={{typeMeta.type}}
                  selected={{this.isTypeSelected typeMeta.type}}
                >{{typeMeta.displayName}}</option>
              {{/each}}
            </select>
          </label>

          {{#if this.editorComponent}}
            <this.editorComponent
              @leaf={{@node}}
              @onChange={{this.onLeafChange}}
            />
          {{else}}
            <ConditionLeafArgs
              @node={{@node}}
              @typeMeta={{@typeMeta}}
              @onChange={{this.onArgChange}}
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
