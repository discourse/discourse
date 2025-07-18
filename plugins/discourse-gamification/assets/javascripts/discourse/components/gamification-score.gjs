import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import fullnumber from "../helpers/fullnumber";

@tagName("span")
@classNames("gamification-score")
export default class GamificationScore extends Component {
  <template>
    {{#if this.site.default_gamification_leaderboard_id}}
      <LinkTo
        @route="gamificationLeaderboard.byName"
        @model={{this.site.default_gamification_leaderboard_id}}
        class="gamification-score__link"
      >
        {{fullnumber this.model.gamification_score}}
      </LinkTo>
    {{else}}
      {{fullnumber this.model.gamification_score}}
    {{/if}}
  </template>
}
