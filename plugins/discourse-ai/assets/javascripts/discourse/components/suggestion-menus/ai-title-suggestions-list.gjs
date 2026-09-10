import { fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

export default <template>
  <DDropdownMenu as |dropdown|>
    {{#each @suggestions as |suggestion index|}}
      <dropdown.item>
        <DButton
          data-name={{suggestion}}
          data-value={{index}}
          title={{suggestion}}
          @action={{fn @onSelect suggestion}}
          @translatedLabel={{suggestion}}
        />
      </dropdown.item>
    {{/each}}
  </DDropdownMenu>
</template>
