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
import ConditionLeafArgsUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/condition-leaf-args";
import OutletArgConditionEditorUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/outlet-arg-condition-editor";
import RouteConditionEditorUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/route-condition-editor";
import SettingConditionEditorUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/setting-condition-editor";
import UserConditionEditorUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/user-condition-editor";
import ViewportConditionEditorUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/editors/viewport-condition-editor";
import { iconForConditionType } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-icons";
import { summarizeLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-summary";

/**
 * A single leaf condition node: a `type` discriminator plus any
 * type-specific args, keyed by arg name. The index signature keeps the
 * shape open because each condition type carries a different arg set.
 */
export interface ConditionLeaf {
  type?: string;
  [arg: string]: unknown;
}

/**
 * Registry entry describing one condition type, as returned by the
 * blocks service's condition-type listing. Used to label rows and to
 * drive the type-switch dropdown; the per-type editors read `argsSchema`
 * to know which inputs to render.
 */
export interface ConditionTypeMeta {
  type: string;
  displayName: string;
  description?: string | null;
  argsSchema?: Record<string, unknown>;
  sourceType?: string;
  constraints?: unknown;
  namespaceType?: string;
}

/**
 * The contract every per-type condition editor honors: it receives the
 * leaf being edited plus its registry entry, and bubbles a fully-formed
 * replacement leaf on each edit.
 */
interface ConditionEditorSignature {
  Args: {
    leaf: ConditionLeaf | undefined;
    typeMeta: ConditionTypeMeta;
    onChange: (nextLeaf: ConditionLeaf) => void;
  };
}
type ConditionEditorComponent = ComponentLike<ConditionEditorSignature>;

// TODO(devxp-typescript-pending): drop each cast once its target editor is
// authored in .gts with a matching Signature and import it directly.
// The per-type editors and the generic arg fallback do not (yet all)
// declare a shared Glint Signature, so cast each to the common contract
// this row relies on at the import boundary. This is a types-only shim
// with no runtime effect.
const UserConditionEditor =
  UserConditionEditorUntyped as unknown as ConditionEditorComponent;
const ViewportConditionEditor =
  ViewportConditionEditorUntyped as unknown as ConditionEditorComponent;
const RouteConditionEditor =
  RouteConditionEditorUntyped as unknown as ConditionEditorComponent;
const SettingConditionEditor =
  SettingConditionEditorUntyped as unknown as ConditionEditorComponent;
const OutletArgConditionEditor =
  OutletArgConditionEditorUntyped as unknown as ConditionEditorComponent;
const ConditionLeafArgs = ConditionLeafArgsUntyped as unknown as ComponentLike<{
  Args: {
    node: ConditionLeaf | undefined;
    typeMeta: ConditionTypeMeta;
    onChange: (name: string, value: unknown) => void;
  };
}>;

interface ConditionRuleSignature {
  Args: {
    node?: ConditionLeaf;
    typeMeta: ConditionTypeMeta;
    conditionTypes: ConditionTypeMeta[];
    onUpdate: (nextLeaf: ConditionLeaf) => void;
    onChangeType: (typeId: string) => void;
    onRemove: () => void;
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
  @tracked expanded: boolean;
  isTypeSelected = (typeId: string) => this.args.node?.type === typeId;

  constructor(owner: Owner, args: ConditionRuleSignature["Args"]) {
    super(owner, args);
    this.expanded = this.args.startExpanded ?? false;
  }

  /**
   * Icon ID representing the rule's condition type. Drives the visual
   * anchor next to each rule row.
   */
  get icon() {
    return iconForConditionType(this.args.node?.type);
  }

  /**
   * Short, human-readable summary of the leaf's current configuration
   * (e.g. "Logged-in users in @staff"). Shown collapsed in the rule
   * header so authors can scan rules without expanding them.
   */
  get summary() {
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

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
  }

  @action
  onArgChange(name: string, value: unknown) {
    const next: ConditionLeaf = { ...this.args.node, [name]: value };
    if (value === undefined) {
      delete next[name];
    }
    this.args.onUpdate(next);
  }

  @action
  onLeafChange(nextLeaf: ConditionLeaf) {
    this.args.onUpdate(nextLeaf);
  }

  @action
  remove() {
    this.args.onRemove();
  }

  @action
  changeType(event: Event) {
    const typeId = (event.target as HTMLSelectElement).value;
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
              @typeMeta={{@typeMeta}}
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
