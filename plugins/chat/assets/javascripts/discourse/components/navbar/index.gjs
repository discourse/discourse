import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import Actions from "./actions";
import BackButton from "./back-button";
import ChannelTitle from "./channel-title";
import Title from "./title";

export default class ChatNavbar extends Component {
  get buttonComponent() {
    return BackButton;
  }

  get titleComponent() {
    return Title;
  }

  get actionsComponent() {
    return Actions;
  }

  get channelTitleComponent() {
    return ChannelTitle;
  }

  <template>
    <div class="c-navbar-container">
      <nav class="c-navbar">
        {{yield
          (hash
            BackButton=this.buttonComponent
            ChannelTitle=this.channelTitleComponent
            Title=this.titleComponent
            Actions=this.actionsComponent
          )
        }}
      </nav>
    </div>
  </template>
}
