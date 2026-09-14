import { i18n } from "discourse-i18n";
import GamificationScore from "../../components/gamification-score";

const GamificationScoreConnector = <template>
  <div class="user-card-metadata-outlet gamification-score" ...attributes>
    {{#if @user.gamification_score}}
      <span class="desc">{{i18n "gamification.score"}} </span>
      <span><GamificationScore @model={{@user}} /></span>
    {{/if}}
  </div>
</template>;

export default GamificationScoreConnector;
