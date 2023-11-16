import Component from "@glimmer/component";
import dIcon from "discourse-common/helpers/d-icon";

export default class ChatComposerButton extends Component {
  <template>
    <div class="chat-composer-button__wrapper">
      <button type="button" class="chat-composer-button" ...attributes>
        {{dIcon @icon}}
      </button>
    </div>
  </template>
}
