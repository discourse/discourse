import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import DButton from "discourse/components/d-button";

const GetARoomComposerMessage = <template>
  <ComposerTipCloseButton @action={{fn @closeMessage @message}} />

  {{htmlSafe @message.body}}

  <DButton
    @label="user.private_message"
    @icon="envelope"
    @action={{fn @switchPM @message}}
    class="btn-primary"
  />
</template>;

export default GetARoomComposerMessage;
