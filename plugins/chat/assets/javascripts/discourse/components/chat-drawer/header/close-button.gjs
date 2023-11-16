import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class extends Component {
  <template>
    <DButton
      @icon="times"
      @action={{@close}}
      @title="chat.close"
      class="btn-flat btn-link chat-drawer-header__close-btn"
    />
  </template>
}
