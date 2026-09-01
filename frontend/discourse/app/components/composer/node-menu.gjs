import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const NodeMenu = <template>
  <DDropdownMenu class={{@data.className}} as |dropdown|>
    {{#each @data.items as |item|}}
      {{#if item.divider}}
        <dropdown.divider />
      {{else}}
        <dropdown.item>
          <DButton
            class={{dConcatClass
              item.className
              (if item.active "--active")
              (if item.dangerous "--dangerous")
            }}
            @icon={{item.icon}}
            @ariaPressed={{item.active}}
            @action={{fn @data.run item}}
          >
            {{item.label}}
          </DButton>
        </dropdown.item>
      {{/if}}
    {{/each}}
  </DDropdownMenu>
</template>;

export default NodeMenu;
