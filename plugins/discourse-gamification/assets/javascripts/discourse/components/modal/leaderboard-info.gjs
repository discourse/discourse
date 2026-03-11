import { trustHTML } from "@ember/template";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const LeaderboardInfo = <template>
  <DModal
    @title={{i18n "gamification.leaderboard.modal.title"}}
    @closeModal={{@closeModal}}
    class="leaderboard-info-modal"
  >
    <:body>
      {{icon "award"}}
      {{trustHTML (i18n "gamification.leaderboard.modal.text")}}
    </:body>
  </DModal>
</template>;

export default LeaderboardInfo;
