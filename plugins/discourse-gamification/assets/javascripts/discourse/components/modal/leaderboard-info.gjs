import { trustHTML } from "@ember/template";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const LeaderboardInfo = <template>
  <DModal
    @title={{i18n "gamification.leaderboard.modal.title"}}
    @closeModal={{@closeModal}}
    class="leaderboard-info-modal"
  >
    <:body>
      {{dIcon "award"}}
      {{trustHTML (i18n "gamification.leaderboard.modal.text")}}
    </:body>
  </DModal>
</template>;

export default LeaderboardInfo;
