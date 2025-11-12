import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import { or } from "discourse/truth-helpers";

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
