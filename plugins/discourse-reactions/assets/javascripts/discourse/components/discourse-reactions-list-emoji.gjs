import Component from "@glimmer/component";
import { service } from "@ember/service";
import emoji from "discourse/helpers/emoji";

export default class DiscourseReactionsListEmoji extends Component {
  @service siteSettings;

  <template>
    <div class="discourse-reactions-list-emoji">
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
