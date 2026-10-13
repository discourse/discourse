import Component from "@glimmer/component";
import { service } from "@ember/service";
import discourseReactionsEmoji from "../helpers/discourse-reactions-emoji";

export default class DiscourseReactionsListEmoji extends Component {
  @service siteSettings;

  get elementId() {
    return `discourse-reactions-list-emoji-${this.args.post.id}-${this.args.reaction.id}`;
  }

  <template>
    <span class="discourse-reactions-list-emoji" id={{this.elementId}}>
      {{#if @reaction.count}}
        {{discourseReactionsEmoji
          @reaction.id
          class=(if
            this.siteSettings.discourse_reactions_desaturated_reaction_panel
            "desaturated"
            ""
          )
        }}
      {{/if}}
    </span>
  </template>
}
