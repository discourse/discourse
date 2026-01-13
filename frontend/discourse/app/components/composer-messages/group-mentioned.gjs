import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";

const GroupMentionedComposerMessage = <template>
  <ComposerTipCloseButton @action={{fn @closeMessage @message}} />
  <div class="composer-popup__content">

    <p>
      {{htmlSafe @message.body}}
    </p>
  </div>
</template>;

export default GroupMentionedComposerMessage;
