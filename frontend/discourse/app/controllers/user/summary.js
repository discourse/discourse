import Controller, { inject as controller } from "@ember/controller";
import { computed } from "@ember/object";
import { alias } from "@ember/object/computed";
import { duration } from "discourse/lib/formatter";

// should be kept in sync with 'UserSummary::MAX_BADGES'
const MAX_BADGES = 6;

export default class UserSummaryController extends Controller {
  @controller("user") userController;

  @alias("userController.model") user;

  @computed("model.badges.length")
  get moreBadges() {
    return this.model?.badges?.length >= MAX_BADGES;
  }

  @computed("model.time_read")
  get timeRead() {
    return duration(this.model?.time_read, { format: "tiny" });
  }

  @computed("model.time_read")
  get timeReadMedium() {
    return duration(this.model?.time_read, { format: "medium" });
  }

  @computed("model.time_read", "model.recent_time_read")
  get showRecentTimeRead() {
    return (
      this.model?.time_read !== this.model?.recent_time_read &&
      this.model?.recent_time_read !== 0
    );
  }

  @computed("model.recent_time_read")
  get recentTimeRead() {
    return this.model?.recent_time_read > 0
      ? duration(this.model?.recent_time_read, { format: "tiny" })
      : null;
  }

  @computed("model.recent_time_read")
  get recentTimeReadMedium() {
    return this.model?.recent_time_read > 0
      ? duration(this.model?.recent_time_read, { format: "medium" })
      : null;
  }
}
