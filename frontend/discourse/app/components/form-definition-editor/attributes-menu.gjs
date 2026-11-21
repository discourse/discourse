import { fn } from "@ember/helper";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";

function toggleAttribute(toggle, close) {
  toggle();
  return close();
}

const Attribute = <template>
  <@item>
    <DButton
      class="btn-transparent form-definition-editor__attribute-option"
      ...attributes
      @action={{fn toggleAttribute @onToggle @close}}
      @ariaPressed={{@active}}
      @icon="check"
      @translatedLabel={{@label}}
    />
  </@item>
</template>;

export default <template>
  <DMenu
    ...attributes
    @ariaLabel={{@title}}
    @icon={{@icon}}
    @inline={{@inline}}
    @label={{@label}}
    @modalForwardRecipient={{@modalForwardRecipient}}
    @title={{@title}}
    @triggerClass="btn-default"
  >
    <:trigger>{{#if @label}}{{dIcon "chevron-down"}}{{/if}}</:trigger>
    <:content as |menu|>
      <DDropdownMenu as |dropdown|>
        {{yield (component Attribute item=dropdown.item close=menu.close)}}
      </DDropdownMenu>
    </:content>
  </DMenu>
</template>
