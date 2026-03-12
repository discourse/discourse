import icon from "discourse/ui-kit/helpers/d-icon";

const ChatComposerButton = <template>
  <div class="chat-composer-button__wrapper">
    <button type="button" class="chat-composer-button" ...attributes>
      {{icon @icon}}
    </button>
  </div>
</template>;

export default ChatComposerButton;
