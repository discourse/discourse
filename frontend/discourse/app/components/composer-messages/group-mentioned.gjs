import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";

const GroupMentionedComposerMessage = <template>
  <ComposerTipCloseButton @action={{fn @closeMessage @message}} />

  <p>
    {{htmlSafe @message.body}}
  </p>
</template>;

export default GroupMentionedComposerMessage;
