import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigContentStatsAndThresholdsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.content.sub_pages.stats_and_thresholds.title");
  }
}
