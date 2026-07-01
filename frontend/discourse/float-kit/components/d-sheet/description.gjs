import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";

const DSheetDescription = <template>
  <div
    id={{@sheet.descriptionId}}
    class="Sheet-description"
    data-d-sheet="description"
    {{didInsert @sheet.registerDescription}}
    {{willDestroy @sheet.unregisterDescription}}
    ...attributes
  >
    {{yield}}
  </div>
</template>;

export default DSheetDescription;
