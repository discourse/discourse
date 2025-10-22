import { i18n } from "discourse-i18n";

const BooleanThree = <template>
  <@field.Select name={{@info.identifier}} as |select|>
    <select.Option @value="Y">
      {{i18n "explorer.types.bool.true"}}
    </select.Option>
    <select.Option @value="N">
      {{i18n "explorer.types.bool.false"}}
    </select.Option>
    <select.Option @value="#null">
      {{i18n "explorer.types.bool.null_"}}
    </select.Option>
  </@field.Select>
</template>;

export default BooleanThree;
