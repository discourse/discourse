import Component from "@glimmer/component";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatMessageMentionWarning extends Component {
  @service currentUser;

  constructor() {
    super(...arguments);
    this.message = fabricators.message({ user: this.currentUser });
  }

  @action
  toggleCannotSee() {
    if (this.message.mentionWarning?.cannotSee) {
      this.message.mentionWarning = null;
    } else {
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          cannot_see: [fabricators.user({ username: "bob" })].map((u) => {
            return { username: u.username, id: u.id };
          }),
        }
      );
    }
  }

  @action
  toggleGroupWithMentionsDisabled() {
    if (this.message.mentionWarning?.groupWithMentionsDisabled) {
      this.message.mentionWarning = null;
    } else {
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          group_mentions_disabled: [fabricators.group()].mapBy("name"),
        }
      );
    }
  }

  @action
  toggleGroupsWithTooManyMembers() {
    if (this.message.mentionWarning?.groupsWithTooManyMembers) {
      this.message.mentionWarning = null;
    } else {
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          groups_with_too_many_members: [
            fabricators.group(),
            fabricators.group({ name: "Moderators" }),
          ].mapBy("name"),
        }
      );
    }
  }
  @action
  toggleWithoutMembership() {
    if (this.message.mentionWarning?.withoutMembership) {
      this.message.mentionWarning = null;
    } else {
      this.message.mentionWarning = fabricators.messageMentionWarning(
        this.message,
        {
          without_membership: [fabricators.user()].map((u) => {
            return { username: u.username, id: u.id };
          }),
        }
      );
    }
  }
}
