import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import fullnumber from "../helpers/fullnumber";

export default class GamificationScore extends Component {
  @service site;

  <template>
    <span class="gamification-score" ...attributes>
      {{#if this.site.default_gamification_leaderboard_id}}
        <LinkTo
          class="gamification-score__link"
          @model={{this.site.default_gamification_leaderboard_id}}
          @route="gamificationLeaderboard.byName"
        >
          {{fullnumber @model.gamification_score}}
        </LinkTo>
      {{else}}
        {{fullnumber @model.gamification_score}}
      {{/if}}
    </span>
  </template>
}
