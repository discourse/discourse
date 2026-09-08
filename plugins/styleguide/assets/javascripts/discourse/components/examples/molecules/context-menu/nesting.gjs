import dContextMenu from "discourse/float-kit/modifiers/d-context-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

const BlockActions = <template>
  <DDropdownMenu as |dropdown|>
    <dropdown.item>
      <DButton
        @label="styleguide.sections.context_menu.actions.duplicate"
        @action={{@close}}
      />
    </dropdown.item>
    <dropdown.item>
      <DButton
        @label="styleguide.sections.context_menu.actions.delete"
        @action={{@close}}
      />
    </dropdown.item>
  </DDropdownMenu>
</template>;

const RowActions = <template>
  <DDropdownMenu as |dropdown|>
    <dropdown.item>
      <DButton
        @label="styleguide.sections.context_menu.actions.rename"
        @action={{@close}}
      />
    </dropdown.item>
  </DDropdownMenu>
</template>;

/**
 * Two surfaces, one inside the other, each with its own menu.
 *
 * The event bubbles, so both would run without arbitration. Accepting stops propagation, which
 * is why the inner surface's menu opens alone rather than alongside its parent's.
 *
 * The only thing either surface does for the keyboard is take focus. Opening at the caret,
 * moving focus into the menu and returning it on close all come from the modifier.
 */
export default <template>
  <div
    class="context-menu-demo__surface"
    tabindex="0"
    {{dContextMenu component=BlockActions}}
  >
    <span class="context-menu-demo__label">
      {{i18n "styleguide.sections.context_menu.nesting.outer"}}
    </span>

    <div
      class="context-menu-demo__surface --nested"
      tabindex="0"
      {{dContextMenu component=RowActions}}
    >
      <span class="context-menu-demo__label">
        {{i18n "styleguide.sections.context_menu.nesting.inner"}}
      </span>
    </div>
  </div>
</template>
