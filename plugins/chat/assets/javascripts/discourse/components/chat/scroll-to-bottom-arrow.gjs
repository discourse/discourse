import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse-common/helpers/d-icon";

export default class extends Component {
  <template>
    <div class="chat-scroll-to-bottom">
      <DButton
        class={{concatClass
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
  </template>
}
