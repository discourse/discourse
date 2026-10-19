import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { translateSize } from "discourse/lib/avatar-utils";
import TopicPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/topic-presence-display";

const AVATAR_SIZE = "small";

export default class Presence extends Component {
  get avatarDimensions() {
    return translateSize(AVATAR_SIZE);
  }

  <template>
    <div
      class="topic-above-footer-buttons-outlet presence"
      style={{trustHTML
        (concat "--avatar-min-height: " this.avatarDimensions "px")
      }}
    >
      <TopicPresenceDisplay
        @avatarSize={{AVATAR_SIZE}}
        @topic={{@outletArgs.model}}
      />
    </div>
  </template>
}
