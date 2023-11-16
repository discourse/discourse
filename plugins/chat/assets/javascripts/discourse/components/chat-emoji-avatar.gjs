import Component from "@glimmer/component";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class extends Component {
  <template>
    <div class="chat-emoji-avatar">
      <div class="chat-emoji-avatar-container">
        {{replaceEmoji @emoji}}
      </div>
    </div>
  </template>
}
