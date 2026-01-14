import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { translateSize } from "discourse/lib/avatar-utils";
import TopicPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/topic-presence-display";

const AVATAR_SIZE = "small";

export default class Presence extends Component {
  get avatarDimensions() {
    return translateSize(AVATAR_SIZE);
  }

  <template>
    <div
      style={{htmlSafe
        (concat "--avatar-min-height: " this.avatarDimensions "px")
      }}
      class="topic-above-footer-buttons-outlet presence"
    >
      <TopicPresenceDisplay
        @topic={{@outletArgs.model}}
        @avatarSize={{AVATAR_SIZE}}
      />
    </div>
  </template>
}
