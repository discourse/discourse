import { fn, get } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  NETWORK_ERROR,
  RATE_LIMIT_COOLDOWN_ERROR,
  RATE_LIMIT_ERROR,
} from "discourse/plugins/chat/discourse/lib/chat-constants";

const RETRY_TITLES = {
  [NETWORK_ERROR]: "chat.retry_staged_message.title",
  [RATE_LIMIT_ERROR]: "chat.retry_staged_message.rate_limited_title",
};

const Error = <template>
  {{#if @message.error}}
    <div class="chat-message-error">
      {{#if (get RETRY_TITLES @message.error)}}
        <DButton
          class="chat-message-error__retry-btn"
          @action={{fn @onRetry @message}}
          @icon="circle-exclamation"
        >
          <span class="chat-message-error__retry-btn-title">
            {{i18n (get RETRY_TITLES @message.error)}}
          </span>
          <span class="chat-message-error__retry-btn-action">
            {{i18n "chat.retry_staged_message.action"}}
          </span>
        </DButton>
      {{else if (eq @message.error RATE_LIMIT_COOLDOWN_ERROR)}}
        {{i18n "chat.retry_staged_message.rate_limited_waiting"}}
      {{else}}
        {{@message.error}}
      {{/if}}
    </div>
  {{/if}}
</template>;

export default Error;
