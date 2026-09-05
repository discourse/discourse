import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DShortcut from "discourse/ui-kit/d-shortcut";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/**
 * Dropdown of actions for a node in the rich editor, shown from its action
 * trigger.
 *
 * Purely presentational: items are plain objects because the callers are
 * ProseMirror plugins rather than components, and build them next to the
 * commands they run. `@data.className` names the list so each caller keeps its
 * own styling hook.
 */
const NodeMenu = <template>
  <DDropdownMenu class={{@data.className}} as |dropdown|>
    {{#each @data.items as |item|}}
      {{#if item.divider}}
        <dropdown.divider />
      {{else}}
        <dropdown.item>
          <DShortcut @keys={{item.shortcutKeys}} as |shortcut|>
            <DButton
              aria-keyshortcuts={{shortcut.aria}}
              class={{dConcatClass
                item.className
                (if item.active "--active")
                (if item.dangerous "--dangerous")
              }}
              @icon={{item.icon}}
              @ariaPressed={{item.active}}
              @action={{fn @data.run item}}
            >
              <span class="d-button-label">
                <span class="d-button-label__text">{{item.label}}</span>
                <shortcut.Kbd class="shortcut" />
              </span>
            </DButton>
          </DShortcut>
        </dropdown.item>
      {{/if}}
    {{/each}}
  </DDropdownMenu>
</template>;

export default NodeMenu;
