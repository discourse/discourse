import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import type { ComponentLike } from "@glint/template";
import { or } from "discourse/truth-helpers";

/** The panel's own controls, for a main block to place. */
export interface PanelDockControls {
  /** The control that moves the panel between viewport edges. */
  DockPicker: ComponentLike<{ Element: HTMLDivElement }>;
}

/** The arguments and blocks for the shared panel interior. */
interface PanelDockInteriorSignature {
  Args: {
    /** Whether the panel offers a dock side picker. */
    dockable?: boolean;

    /** The dock picker pre-wired to the panel's current side and setter. */
    dockPicker: ComponentLike<{ Element: HTMLDivElement }>;

    /** Whether the chassis caller supplied an actions block. */
    hasActions: boolean;

    /** Whether the chassis caller supplied a header block. */
    hasHeader: boolean;

    /** Whether the chassis caller supplied a main block. */
    hasMain: boolean;
  };
  Blocks: {
    /** The panel's header row. */
    header: [];

    /** Controls rendered at the end of the header row. */
    actions: [];

    /** The panel's content. */
    body: [];

    /** The panel's whole interior, replacing the header row and body. */
    main: [controls: PanelDockControls];
  };
}

/** The shared interior of every panel rendering host. */
const PanelDockInterior: TemplateOnlyComponent<PanelDockInteriorSignature> =
  <template>
    {{#if @hasMain}}
      {{yield (hash DockPicker=@dockPicker) to="main"}}
    {{else}}
      {{! The header row also hosts the dock picker and the caller's actions,
          so it must render whenever any of the three exist — otherwise a
          headerless dockable panel would silently lose its controls. }}
      {{#if (or @hasHeader @dockable @hasActions)}}
        <div class="d-panel-dock__header">
          {{yield to="header"}}

          <div class="d-panel-dock__actions">
            {{#if @dockable}}
              <@dockPicker />
            {{/if}}

            {{yield to="actions"}}
          </div>
        </div>
      {{/if}}

      <div class="d-panel-dock__body">
        {{yield to="body"}}
      </div>
    {{/if}}
  </template>;

export default PanelDockInterior;
