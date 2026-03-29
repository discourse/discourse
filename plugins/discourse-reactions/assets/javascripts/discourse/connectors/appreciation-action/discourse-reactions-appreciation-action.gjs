import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import { emojiUrlFor } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";

export default class DiscourseReactionsAppreciationAction extends Component {
  get shouldRender() {
    return this.args.outletArgs.item?.appreciation_type === "reaction";
  }

  get emojiUrl() {
    const reactionValue = this.args.outletArgs.item?.metadata?.reaction_value;
    return reactionValue ? emojiUrlFor(reactionValue) : null;
  }

  get actingUser() {
    return this.args.outletArgs.item?.acting_user;
  }

  <template>
    {{#if this.shouldRender}}
      <a
        href={{userPath this.actingUser.username}}
        data-user-card={{this.actingUser.username}}
        class="avatar-link"
      >
        <div class="avatar-wrapper">
          {{avatar this.actingUser imageSize="tiny"}}
        </div>
      </a>
      {{#if this.emojiUrl}}
        <img src={{this.emojiUrl}} class="reaction-emoji" />
      {{/if}}
    {{/if}}
  </template>
}
