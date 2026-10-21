import Component from "@glimmer/component";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import discourseReactionsEmoji from "../helpers/discourse-reactions-emoji.js";

export default class DiscourseReactionsReactionEmoji extends Component {
  get reactionValue() {
    return this.args.reaction.reaction?.reaction_value;
  }

  <template>
    {{#if @reaction.reaction.reaction_users_count}}
      <div class="discourse-reactions-my-reaction">
        {{#if this.reactionValue}}
          {{discourseReactionsEmoji this.reactionValue class="reaction-emoji"}}
        {{/if}}
        <a
          class="avatar-link"
          data-user-card={{@reaction.user.username}}
          href={{@reaction.user.userUrl}}
        >
          {{dAvatar
            @reaction.user
            imageSize="tiny"
            extraClasses="actor"
            ignoreTitle="true"
          }}
        </a>
      </div>
    {{/if}}
  </template>
}
