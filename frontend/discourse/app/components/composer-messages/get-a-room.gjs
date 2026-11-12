import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import DButton from "discourse/ui-kit/d-button";

const GetARoomComposerMessage = <template>
  <ComposerTipCloseButton @action={{fn @closeMessage @message}} />

  <div class="composer-popup__content">

    {{trustHTML @message.body}}

    <DButton
      class="btn-primary"
      @action={{fn @switchPM @message}}
      @icon="envelope"
      @label="user.private_message"
    />
  </div>
</template>;

export default GetARoomComposerMessage;
