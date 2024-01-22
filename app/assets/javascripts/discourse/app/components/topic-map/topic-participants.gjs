import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import { userPath } from "discourse/lib/url";
import { avatarImg } from "discourse-common/lib/avatar-utils";
import gt from "truth-helpers/helpers/gt";

let addTopicParticipantClassesCallbacks = [];

export function addTopicParticipantClassesCallback(callback) {
  addTopicParticipantClassesCallbacks =
    addTopicParticipantClassesCallbacks || [];
  addTopicParticipantClassesCallbacks.push(callback);
}

class TopicParticipant extends Component {
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
      addTopicParticipantClassesCallbacks?.map((callback) =>
        callback(this.args.participant)
      ),
    ]
      .filter(Boolean)
      .flat(3)
      .join(" ");
  }

  get linkClasses() {
    return ["poster", "trigger-user-card", this.args.toggled ? "toggled" : null]
      .filter(Boolean)
      .join(" ");
  }

  get userUrl() {
    userPath(this.args.participant);
  }

  <template>
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
  </template>
}

export default class TopicParticipants extends Component {
  filteredUsers;

  constructor() {
    super(...arguments);
    this.filteredUsers = new Set(this.args.userFilters);
  }

  shouldToggle(participant) {
    return this.filteredUsers.has(participant.username);
  }

  <template>
    {{@title}}
    {{#each @participants as |participant|}}
      <TopicParticipant
        @participant={{participant}}
        @toggled={{(fn this.shouldToggle participant)}}
      />
    {{/each}}
  </template>
}
