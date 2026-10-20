import { fn } from "@ember/helper";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";

const ShareSource = <template>
  <DButton
    class="btn-default share-{{@source.id}}"
    ...attributes
    @action={{fn @action @source}}
    @icon={{or @source.icon @source.htmlIcon}}
    @translatedTitle={{@source.title}}
  />
</template>;

export default ShareSource;
