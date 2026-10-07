import Component from "@glimmer/component";
import { service } from "@ember/service";
import DiscourseReactionsListEmoji from "./discourse-reactions-list-emoji";

export default class DiscourseReactionsList extends Component {
  @service siteSettings;

  get reactions() {
    const { reactions } = this.args.post;

    // Every reaction renders as the like icon without emoji, so show it once.
    if (!this.siteSettings.enable_emoji && reactions?.length) {
      return [
        {
          id: this.siteSettings.discourse_reactions_reaction_for_like,
          count: this.args.post.reaction_users_count,
        },
      ];
    }

    return reactions;
  }

  <template>
    <span class="discourse-reactions-list" ...attributes>
      {{#if @post.reaction_users_count}}
        <span class="reactions">
          {{#each this.reactions as |reaction|}}
            <DiscourseReactionsListEmoji
              @post={{@post}}
              @reaction={{reaction}}
            />
          {{/each}}
        </span>
      {{/if}}
    </span>
  </template>
}
