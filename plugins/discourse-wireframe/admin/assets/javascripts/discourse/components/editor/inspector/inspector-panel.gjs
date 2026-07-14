// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKAlert from "discourse/form-kit/components/fk/alert";
import { isPartKey } from "discourse/lib/blocks/-internals/composite";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ConditionsTree from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/conditions-tree";
import InspectorContainerArgsForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-container-args-form";
import InspectorForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-form";
import InspectorLayoutForm from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-layout-form";
import InspectorMetadataSection from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-metadata-section";
import InspectorOutletSection from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-outlet-section";
import InspectorRawJson from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-raw-json";
/** @type {import("../palette/block-thumbnail.gjs").default} */
import BlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-thumbnail";
/** @type {import("../palette/outlet-thumbnail.gjs").default} */
import OutletThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/outlet-thumbnail";

/**
 * Inspector for the selected block. Organises content into a tab strip
 * (Args / Conditions / Raw JSON). Metadata surfaces via a small `ⓘ`
 * button next to the block name with a tooltip — it's reference info,
 * not edit info, and doesn't deserve its own pane.
 */
export default class InspectorPanel extends Component {
  @service blocks;
  @service wireframeBlockMutations;
  @service wireframeConditionsPanel;
  @service wireframeLayoutQuery;
  @service wireframeSelection;

  isTabActive = (tab) => this.currentTab === tab;
  @tracked _activeTab = "args";

  /**
   * The effective active tab. The outlet root has no Conditions tab (a page
   * region doesn't carry visibility conditions), so a lingering "conditions"
   * selection from a previous block falls back to "args". A synthesized
   * composite part shows only the Args tab (no conditions, no raw entry), so
   * any other lingering selection falls back to "args" too.
   *
   * @returns {string}
   */
  get currentTab() {
    if (this.isPart) {
      return "args";
    }
    if (this.isOutletRoot && this._activeTab === "conditions") {
      return "args";
    }
    return this._activeTab;
  }

  /**
   * Whether the current selection is a synthesized composite part (no
   * persisted entry). Parts have no visibility conditions and no real entry
   * to inspect raw, so the inspector shows only the Args tab for them.
   *
   * @returns {boolean}
   */
  get isPart() {
    return isPartKey(this.wireframeSelection.selectedBlockKey);
  }

  /**
   * Whether the current selection is an outlet's implicit root layout. The
   * inspector presents it AS the outlet: the layout form for arranging the
   * region, but no Conditions tab and no id / classNames metadata (the outlet
   * already owns its identity).
   *
   * @returns {boolean}
   */
  get isOutletRoot() {
    return this.wireframeLayoutQuery.isOutletRoot(
      this.wireframeSelection.selectedBlockKey
    );
  }

  /**
   * The selected outlet's display metadata (friendly name, description), or
   * `null` when the selection isn't an outlet root. Resolved from the outlet
   * registry by name so the inspector presents the outlet's own identity
   * rather than the implicit root layout block's.
   *
   * @returns {Object|null}
   */
  get #outletMeta() {
    if (!this.isOutletRoot) {
      return null;
    }
    return this.blocks.getOutletMetadata(this.data?.outletName);
  }

  /**
   * The name shown in the inspector header. Prefers human-readable labels over
   * raw registry names:
   *
   * - For an outlet root, the outlet's display name (the region the author
   *   selected), falling back to the raw outlet name.
   * - For a registered block, the block's `displayName`, then its namespace-less
   *   `shortName`.
   * - For an unregistered block (no metadata), the raw block name, since the
   *   editor has no friendlier label to offer.
   *
   * @returns {string}
   */
  get displayTitle() {
    if (this.isOutletRoot) {
      return this.#outletMeta?.displayName ?? this.data?.outletName;
    }
    return (
      this.metadata?.displayName ?? this.metadata?.shortName ?? this.data?.name
    );
  }

  /**
   * Whether the header should render a thumbnail preview. True for an outlet
   * root (which shows its own designed thumbnail regardless of the layout
   * block's metadata) and for any selection that carries block metadata.
   *
   * @returns {boolean}
   */
  get showPreview() {
    return this.isOutletRoot || this.metadata != null;
  }

  /**
   * `true` when a block is currently selected and the inspector has
   * something to render.
   *
   * @returns {boolean}
   */
  get hasSelection() {
    return this.wireframeSelection.selectedBlockData != null;
  }

  /**
   * `true` when more than one block is selected — the inspector then shows a
   * bulk-action summary instead of the per-block form.
   *
   * @returns {boolean}
   */
  get hasMultiSelection() {
    return this.wireframeSelection.hasMultiSelection;
  }

  /** @returns {number} How many blocks are currently selected. */
  get selectionCount() {
    return this.wireframeSelection.selectionCount;
  }

  /**
   * Live data for the selected block, or `null` when nothing is
   * selected. Pulled from the service so the inspector tracks the
   * latest live values without holding its own snapshot.
   *
   * @returns {Object|null}
   */
  get data() {
    return this.wireframeSelection.selectedBlockData;
  }

  /**
   * Block metadata for the selected block (args schema, description,
   * etc.), or `null` when the registry has no entry.
   *
   * @returns {Object|null}
   */
  get metadata() {
    return this.data?.metadata ?? null;
  }

  /**
   * Whether the selected block's type isn't registered. The editor has no
   * schema for it, so every inspector surface is read-only and a notice
   * explains why. The flag is set on the selection data by the service at
   * selection time.
   *
   * @returns {boolean}
   */
  get isUnregistered() {
    return this.data?.isRegistered === false;
  }

  /**
   * Whether the inspector should render the editable form. True if either
   * the block declared an `args` schema OR the layout passes any args at
   * runtime (in which case `InspectorForm` falls back to an inferred
   * schema). Blocks with no schema and no args still show "no arguments".
   */
  get hasArgsSchema() {
    const declaredArgs = this.metadata?.args;
    if (declaredArgs && Object.keys(declaredArgs).length > 0) {
      return true;
    }
    const liveArgs = this.data?.args;
    return !!(liveArgs && Object.keys(liveArgs).length > 0);
  }

  /**
   * Whether the selected block deserves a bespoke args form instead of
   * the generic FormKit one. The `wf:layout` block gets a custom form
   * that surfaces mode-specific controls — segmented mode picker,
   * columns/rows steppers, gap slider, template disclosure. Other
   * blocks fall through to the generic form.
   *
   * @returns {boolean}
   */
  get hasCustomLayoutForm() {
    return this.data?.name === "layout";
  }

  /**
   * Whether the selected entry should render a placement form. True when
   * its parent declares a `childArgs` schema — for the current visual
   * editor that's the `wf:layout` block, so direct children of a grid /
   * stack / row layout get an extra inspector section to edit their
   * `containerArgs.<mode>` placement hints.
   *
   * @returns {boolean}
   */
  get hasContainerArgsForm() {
    return this.data?.parentChildArgsSchema != null;
  }

  /**
   * Text shown in the header's `ⓘ` tooltip. Keeps reference trivia out of the
   * main pane. For an outlet root it's the outlet's description (block-level
   * trivia like namespace / container flag is meaningless for a page region),
   * which is `null` when the outlet declares none — the header hides the icon
   * in that case. For a block it's the three-line namespace / description /
   * container summary.
   *
   * @returns {string|null}
   */
  get metadataTooltip() {
    if (this.isOutletRoot) {
      return this.#outletMeta?.description ?? null;
    }
    const parts = [];
    if (this.metadata?.namespace) {
      parts.push(
        `${i18n("wireframe.inspector.label_namespace")}: ${this.metadata.namespace}`
      );
    }
    if (this.metadata?.description) {
      parts.push(this.metadata.description);
    }
    parts.push(
      `${i18n("wireframe.inspector.label_is_container")}: ${
        this.metadata?.isContainer ? "yes" : "no"
      }`
    );
    return parts.join("\n");
  }

  /**
   * Whether the Args tab contains validation errors and should render
   * the warning badge on its tab button. Today every structured detail
   * we emit is either field-attributed (under an arg) or block-level
   * (constraints, structural). Both belong to Args content, so the
   * Args tab badges when either bucket is non-empty.
   *
   * Conditions / Raw JSON tabs don't badge yet — the validator doesn't
   * attribute condition errors to a `condition` scope, and Raw JSON is
   * read-only.
   *
   * @returns {boolean}
   */
  get argsTabHasErrors() {
    // The unregistered-block notice above the tabs already owns this signal,
    // so we don't also flag the Args tab — that would duplicate the message
    // (the same validation error backs both).
    if (this.isUnregistered) {
      return false;
    }
    return this.wireframeSelection.selectedBlockHasErrors;
  }

  @action
  removeSelectedBlock() {
    // The only recovery for an unregistered block is to replace its name or
    // drop it; the notice surfaces the latter as a one-click action.
    this.wireframeBlockMutations.removeBlock(
      this.wireframeSelection.selectedBlockKey
    );
  }

  @action
  removeSelectedBlocks() {
    this.wireframeBlockMutations.removeBlocks(
      this.wireframeSelection.selectedKeysSnapshot()
    );
  }

  @action
  setTab(tab) {
    this._activeTab = tab;
  }

  @action
  toggleDetachConditions() {
    this.wireframeConditionsPanel.toggleDetached();
  }

  <template>
    {{#if this.hasMultiSelection}}
      <div class="wireframe-inspector__multi">
        <span class="wireframe-inspector__multi-count">
          {{i18n
            "wireframe.inspector.multi.selected_count"
            count=this.selectionCount
          }}
        </span>
        <DButton
          class="btn-danger wireframe-inspector__multi-delete"
          @icon="trash-can"
          @label="wireframe.inspector.multi.delete"
          @action={{this.removeSelectedBlocks}}
        />
      </div>
    {{else if this.hasSelection}}
      <div class="wireframe-inspector__header">
        {{#if this.showPreview}}
          <div class="wireframe-inspector__preview">
            {{#if this.isOutletRoot}}
              {{! An outlet is a page region, not a block, so it gets its own
                  designed thumbnail rather than the implicit root layout
                  block's icon placeholder. }}
              <OutletThumbnail class="wireframe-inspector__thumbnail" />
            {{else}}
              <BlockThumbnail
                class="wireframe-inspector__thumbnail"
                @thumbnail={{this.metadata.thumbnail}}
                @icon={{or this.metadata.icon "cube"}}
              />
            {{/if}}
          </div>
        {{/if}}
        <span class="wireframe-inspector__block-name">
          {{this.displayTitle}}
        </span>
        {{#if this.metadataTooltip}}
          <span
            class="wireframe-inspector__metadata-info"
            title={{this.metadataTooltip}}
            aria-label={{this.metadataTooltip}}
          >
            {{dIcon "circle-info"}}
          </span>
        {{/if}}
      </div>

      {{#if this.isUnregistered}}
        <FKAlert
          @type="error"
          @icon="triangle-exclamation"
          class="wireframe-inspector__unregistered-notice"
          role="note"
        >
          <strong>{{i18n
              "wireframe.inspector.unregistered_notice_title"
            }}</strong>
          <span>{{i18n "wireframe.inspector.unregistered_notice"}}</span>
          <DButton
            class="btn-danger btn-small wireframe-inspector__unregistered-notice-action"
            @icon="trash-can"
            @label="wireframe.inspector.unregistered_notice_remove"
            @action={{this.removeSelectedBlock}}
          />
        </FKAlert>
      {{/if}}

      {{#if this.isOutletRoot}}
        <InspectorOutletSection @outletName={{this.data.outletName}} />
      {{else}}
        <InspectorMetadataSection />
      {{/if}}

      <div class="wireframe-inspector__tabs" role="tablist">
        <DButton
          class={{dConcatClass
            "btn-flat wireframe-inspector__tab"
            (if (this.isTabActive "args") "--active")
            (if this.argsTabHasErrors "--has-errors")
          }}
          @label="wireframe.inspector.tab_args"
          @icon={{if this.argsTabHasErrors "triangle-exclamation"}}
          @action={{fn this.setTab "args"}}
        />
        {{#unless (or this.isOutletRoot this.isPart)}}
          <DButton
            class={{dConcatClass
              "btn-flat wireframe-inspector__tab"
              (if (this.isTabActive "conditions") "--active")
            }}
            @label="wireframe.inspector.tab_conditions"
            @action={{fn this.setTab "conditions"}}
          />
        {{/unless}}
        {{#unless this.isPart}}
          <DButton
            class={{dConcatClass
              "btn-flat wireframe-inspector__tab"
              (if (this.isTabActive "raw") "--active")
            }}
            @label="wireframe.inspector.tab_raw"
            @action={{fn this.setTab "raw"}}
          />
        {{/unless}}
      </div>

      <div class="wireframe-inspector__body">
        {{#if (this.isTabActive "args")}}
          {{#if this.hasCustomLayoutForm}}
            <InspectorLayoutForm />
          {{else if this.hasArgsSchema}}
            <InspectorForm />
          {{else}}
            <div class="panel-empty">
              {{i18n "wireframe.inspector.label_no_args"}}
            </div>
          {{/if}}
          {{#if this.hasContainerArgsForm}}
            <InspectorContainerArgsForm />
          {{/if}}
        {{else if (this.isTabActive "conditions")}}
          <div class="wireframe-inspector__conditions-header">
            <DButton
              class="btn-flat wireframe-inspector__detach-btn"
              @icon={{if
                this.wireframeConditionsPanel.detached
                "down-left-and-up-right-to-center"
                "up-right-and-down-left-from-center"
              }}
              @label={{if
                this.wireframeConditionsPanel.detached
                "wireframe.inspector.conditions.redock_panel"
                "wireframe.inspector.conditions.detach_panel"
              }}
              @title="wireframe.inspector.conditions.detach_panel"
              @action={{this.toggleDetachConditions}}
            />
          </div>
          {{#if this.wireframeConditionsPanel.detached}}
            <p class="wireframe-inspector__conditions-stub">
              {{i18n "wireframe.inspector.conditions.detached_stub"}}
            </p>
          {{else}}
            <ConditionsTree />
          {{/if}}
        {{else}}
          <InspectorRawJson />
        {{/if}}
      </div>
    {{else}}
      <div class="panel-empty">{{i18n "wireframe.inspector.empty"}}</div>
    {{/if}}
  </template>
}
