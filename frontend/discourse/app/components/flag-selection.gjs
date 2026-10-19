import { i18n } from "discourse-i18n";

const FlagSelection = <template>
  <div ...attributes>
    {{#each @flags as |f|}}
      {{yield f}}
    {{else}}
      {{i18n "flagging.cant"}}
    {{/each}}
  </div>
</template>;

export default FlagSelection;
