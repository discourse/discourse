import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const ScrollToBottomArrow = <template>
  <div class="chat-scroll-to-bottom">
    <DButton
      class={{dConcatClass
        "btn-flat"
        "chat-scroll-to-bottom__button"
        (if @isVisible "visible")
      }}
      @action={{@onScrollToBottom}}
    >
      <span class="chat-scroll-to-bottom__arrow">
        {{dIcon "arrow-down"}}
      </span>
    </DButton>
  </div>
</template>;

export default ScrollToBottomArrow;
