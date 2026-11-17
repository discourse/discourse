import { fn } from "@ember/helper";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const CollectionAddMenu = <template>
  <DMenu
    class="btn btn-default workflows-property-engine__add-attrs-btn"
    @inline={{true}}
    @modalForwardRecipient={{true}}
  >
    <:trigger>
      {{@label}}
      {{dIcon "chevron-down"}}
    </:trigger>
    <:content as |menu|>
      <DDropdownMenu as |dropdown|>
        {{#if @addAllLabel}}
          <dropdown.item>
            <DButton
              class="btn-transparent workflows-property-engine__add-all"
              @action={{fn @onAddAll menu.close}}
              @translatedLabel={{@addAllLabel}}
            />
          </dropdown.item>
          <dropdown.divider />
        {{/if}}
        {{#each @options key="name" as |option|}}
          <dropdown.item>
            <DButton
              class="btn-transparent"
              @action={{fn @onAdd option menu.close}}
              @translatedLabel={{if
                @optionLabel
                (@optionLabel option)
                option.name
              }}
            />
          </dropdown.item>
        {{/each}}
      </DDropdownMenu>
    </:content>
  </DMenu>
</template>;

export default CollectionAddMenu;
