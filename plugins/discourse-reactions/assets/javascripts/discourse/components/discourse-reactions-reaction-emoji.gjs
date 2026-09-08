import Component from "@glimmer/component";
import { emojiUrlFor } from "discourse/lib/text";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

export default class DiscourseReactionsReactionEmoji extends Component {
  get emojiUrl() {
    const reactionValue = this.args.reaction.reaction?.reaction_value;
    return reactionValue ? emojiUrlFor(reactionValue) : null;
  }

  <template>
    {{#if @reaction.reaction.reaction_users_count}}
      <div class="discourse-reactions-my-reaction">
        <img class="reaction-emoji" src={{this.emojiUrl}} />
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
