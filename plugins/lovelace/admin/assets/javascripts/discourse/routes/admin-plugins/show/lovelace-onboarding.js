import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class LovelaceOnboardingRoute extends DiscourseRoute {
  model() {
    return ajax("/lovelace/admin/checklist.json");
  }
}
