import dIcon from "discourse/ui-kit/helpers/d-icon";

const ChatComposerButton = <template>
  <div class="chat-composer-button__wrapper">
    <button class="chat-composer-button" type="button" ...attributes>
      {{dIcon @icon}}
    </button>
  </div>
</template>;

export default ChatComposerButton;
