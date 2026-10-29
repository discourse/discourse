import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class LovelaceChecklistRoute extends DiscourseRoute {
  model() {
    return ajax("/lovelace/checklist.json");
  }
}
