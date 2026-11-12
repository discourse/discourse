import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dContextMenu from "discourse/float-kit/modifiers/d-context-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

const SurfaceActions = <template>
  <DDropdownMenu as |dropdown|>
    <dropdown.item>
      <DButton
        @action={{@close}}
        @label="styleguide.sections.context_menu.actions.duplicate"
      />
    </dropdown.item>
  </DDropdownMenu>
</template>;

/**
 * A hook that declines over the text field.
 *
 * Declining leaves the event untouched, so the browser opens its own menu and its spelling and
 * clipboard commands still work. The modifier does this for any caret-owning target by default;
 * the hook here only reports the decision so it is visible.
 */
export default class ContextMenuDecliningExample extends Component {
  @tracked decision;

  get decisionLabel() {
    if (!this.decision) {
      return i18n("styleguide.sections.context_menu.declining.untouched");
    }

    return i18n(`styleguide.sections.context_menu.declining.${this.decision}`);
  }

  @action
  acceptOutsideTheField(event) {
    const accepted = !event.target.closest("input");
    this.decision = accepted ? "accepted" : "declined";
    return accepted;
  }

  <template>
    <div
      class="context-menu-demo__surface"
      tabindex="0"
      {{dContextMenu
        component=SurfaceActions
        beforeContextMenu=this.acceptOutsideTheField
      }}
    >
      <span class="context-menu-demo__label">
        {{i18n "styleguide.sections.context_menu.declining.surface"}}
      </span>

      <input
        class="context-menu-demo__field"
        type="text"
        value={{i18n "styleguide.sections.context_menu.declining.field"}}
      />

      <output
        class="context-menu-demo__decision"
      >{{this.decisionLabel}}</output>
    </div>
  </template>
}
