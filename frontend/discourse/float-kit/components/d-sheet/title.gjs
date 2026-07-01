import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";

const DSheetTitle = <template>
  <h2
    id={{@sheet.titleId}}
    class={{concatClass "Sheet-title" @class}}
    data-d-sheet="title"
    {{didInsert @sheet.registerTitle}}
    {{willDestroy @sheet.unregisterTitle}}
    ...attributes
  >
    {{yield}}
  </h2>
</template>;

export default DSheetTitle;
