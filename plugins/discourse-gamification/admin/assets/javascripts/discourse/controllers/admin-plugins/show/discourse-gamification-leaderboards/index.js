import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import RecalculateScoresForm from "discourse/plugins/discourse-gamification/discourse/components/modal/recalculate-scores-form";

export default class AdminPluginsShowDiscourseGamificationLeaderboardsIndexController extends Controller {
  @service modal;
  @service dialog;
  @service toasts;

  creatingNew = false;

  @discourseComputed("model.leaderboards.@each.updatedAt")
  sortedLeaderboards(leaderboards) {
    return leaderboards?.sortBy("updatedAt").reverse() || [];
  }

  @action
  resetNewLeaderboard() {
    this.set("creatingNew", false);
  }

  @action
  destroyLeaderboard(leaderboard) {
    this.dialog.deleteConfirm({
      message: i18n("gamification.leaderboard.confirm_destroy"),
      didConfirm: () => {
        return ajax(
          `/admin/plugins/gamification/leaderboard/${leaderboard.id}`,
          {
            type: "DELETE",
          }
        )
          .then(() => {
            this.toasts.success({
              duration: 3000,
              data: {
                message: i18n("gamification.leaderboard.delete_success"),
              },
            });
            this.model.leaderboards.removeObject(leaderboard);
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  recalculateScores() {
    this.modal.show(RecalculateScoresForm, {
      model: this.model,
    });
  }

  parseDate(date) {
    if (date) {
      // using the format YYYY-MM-DD returns the previous day for some timezones
      return date.replace(/-/g, "/");
    }
  }
}
