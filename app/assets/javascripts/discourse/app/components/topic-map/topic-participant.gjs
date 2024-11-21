import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import { userPath } from "discourse/lib/url";
import { avatarImg } from "discourse-common/lib/avatar-utils";

const addTopicParticipantClassesCallbacks = [];

export function addTopicParticipantClassesCallback(callback) {
  addTopicParticipantClassesCallbacks.push(callback);
}

export default class TopicParticipant extends Component {
  get avatarImage() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.participant.avatar_template,
        size: "medium",
        title: this.args.participant.name || this.args.participant.username,
      })
    );
  }

  get participantClasses() {
    const { primary_group_name } = this.args.participant;
    return [
      primary_group_name ? `group-${primary_group_name}` : null,
      addTopicParticipantClassesCallbacks.map((callback) =>
        callback(this.args.participant)
      ),
    ]
      .filter(Boolean)
      .flat(3)
      .join(" ");
  }

  get linkClasses() {
    return [
      "poster",
      "trigger-user-card",
      this.args.toggledUsers?.has(this.args.participant.username)
        ? "toggled"
        : null,
    ]
      .filter(Boolean)
      .join(" ");
  }

  get userUrl() {
    return userPath(this.args.participant.username);
  }

  <template>
    <PluginOutlet
      @name="topic-participant"
      @outletArgs={{hash participant=@participant}}
    >
      <div class={{this.participantClasses}}>
        <a
          class={{this.linkClasses}}
          data-user-card={{@participant.username}}
          title={{@participant.username}}
          href={{this.userUrl}}
        >
          {{this.avatarImage}}
          {{#if (gt @participant.post_count 1)}}
            <span class="post-count">{{@participant.post_count}}</span>
          {{/if}}
          <UserAvatarFlair @user={{@participant}} />
        </a>
      </div>
    </PluginOutlet>
  </template>
}
