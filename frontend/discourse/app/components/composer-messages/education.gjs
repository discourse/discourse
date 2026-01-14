import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";

const EducationComposerMessage = <template>
  <ComposerTipCloseButton @action={{fn @closeMessage @message}} />

  <div class="composer-popup__content">
    {{#if @message.title}}
      <h3>{{@message.title}}</h3>
    {{/if}}

    {{htmlSafe @message.body}}
  </div>
</template>;

export default EducationComposerMessage;
