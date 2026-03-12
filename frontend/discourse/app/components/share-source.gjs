import { fn } from "@ember/helper";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";

const ShareSource = <template>
  <DButton
    @action={{fn @action @source}}
    @translatedTitle={{@source.title}}
    @icon={{or @source.icon @source.htmlIcon}}
    class="btn-default share-{{@source.id}}"
    ...attributes
  />
</template>;

export default ShareSource;
