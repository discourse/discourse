import DiscourseRoute from "discourse/routes/discourse";
import { hash } from "rsvp";

export default class AutomationNew extends DiscourseRoute {
  controllerName = "admin-plugins-discourse-automation-new";

  model() {
    return hash({
      scriptables: this.store.findAll("discourse-automation-scriptable"),
      automation: this.store.createRecord("discourse-automation-automation"),
    });
  }
}
