import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";
import { emojiUrlFor } from "discourse/lib/text";

export default class DiscourseReactionsReactionEmoji extends Component {
  get emojiUrl() {
    const reactionValue = this.args.reaction.reaction?.reaction_value;
    return reactionValue ? emojiUrlFor(reactionValue) : null;
  }

  <template>
    {{#if @reaction.reaction.reaction_users_count}}
      <div class="discourse-reactions-my-reaction">
        <img src={{this.emojiUrl}} class="reaction-emoji" />
        <a
          href={{@reaction.user.userUrl}}
          data-user-card={{@reaction.user.username}}
          class="avatar-link"
        >
          {{avatar
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
