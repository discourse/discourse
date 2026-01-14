import { i18n } from "discourse-i18n";
import GamificationScore from "../../components/gamification-score";

const GamificationScoreConnector = <template>
  {{#if @model.gamification_score}}
    <div>
      <dt>
        {{i18n "gamification.score"}}
      </dt>
      <dd>
        <GamificationScore @model={{@model}} />
      </dd>
    </div>
  {{/if}}
</template>;

export default GamificationScoreConnector;
