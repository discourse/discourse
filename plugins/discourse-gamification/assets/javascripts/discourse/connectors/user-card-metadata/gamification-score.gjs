/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import GamificationScore from "../../components/gamification-score";

@tagName("")
export default class GamificationScoreConnector extends Component {
  <template>
    <div class="user-card-metadata-outlet gamification-score" ...attributes>
      {{#if this.user.gamification_score}}
        <span class="desc">{{i18n "gamification.score"}} </span>
        <span><GamificationScore @model={{this.user}} /></span>
      {{/if}}
    </div>
  </template>
}
