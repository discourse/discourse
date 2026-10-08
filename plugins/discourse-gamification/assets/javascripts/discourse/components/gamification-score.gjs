/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { tagName } from "@ember-decorators/component";
import fullnumber from "../helpers/fullnumber";

@tagName("")
export default class GamificationScore extends Component {
  <template>
    <span class="gamification-score" ...attributes>
      {{#if this.site.default_gamification_leaderboard_id}}
        <LinkTo
          class="gamification-score__link"
          @model={{this.site.default_gamification_leaderboard_id}}
          @route="gamificationLeaderboard.byName"
        >
          {{fullnumber this.model.gamification_score}}
        </LinkTo>
      {{else}}
        {{fullnumber this.model.gamification_score}}
      {{/if}}
    </span>
  </template>
}
