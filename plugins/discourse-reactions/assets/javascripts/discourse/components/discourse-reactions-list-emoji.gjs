import Component from "@glimmer/component";
import { service } from "@ember/service";
import emoji from "discourse/helpers/emoji";

export default class DiscourseReactionsListEmoji extends Component {
  @service siteSettings;

  get elementId() {
    return `discourse-reactions-list-emoji-${this.args.post.id}-${this.args.reaction.id}`;
  }

  <template>
    <div class="discourse-reactions-list-emoji" id={{this.elementId}}>
      {{#if @reaction.count}}
        {{emoji
          @reaction.id
          skipTitle=true
          class=(if
            this.siteSettings.discourse_reactions_desaturated_reaction_panel
            "desaturated"
            ""
          )
        }}
      {{/if}}
    </div>
  </template>
}
