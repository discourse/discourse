import PreloadStore from "discourse/lib/preload-store";
import Badge from "discourse/models/badge";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class BadgesIndex extends DiscourseRoute {
  model() {
    if (PreloadStore.get("badges")) {
      return PreloadStore.getAndRemove("badges").then((json) =>
        Badge.createFromJson(json)
      );
    } else {
      return Badge.findAll({ onlyListable: true });
    }
  }

  titleToken() {
    return i18n("badges.title");
  }
}
