import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";

const GroupMentionedComposerMessage = <template>
  <ComposerTipCloseButton @action={{fn @closeMessage @message}} />
  <div class="composer-popup__content">

    <p>
      {{trustHTML @message.body}}
    </p>
  </div>
</template>;

export default GroupMentionedComposerMessage;
