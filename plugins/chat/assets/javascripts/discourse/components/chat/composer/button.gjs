import dIcon from "discourse/helpers/d-icon";

const ChatComposerButton = <template>
  <div class="chat-composer-button__wrapper">
    <button type="button" class="chat-composer-button" ...attributes>
      {{dIcon @icon}}
    </button>
  </div>
</template>;

export default ChatComposerButton;
