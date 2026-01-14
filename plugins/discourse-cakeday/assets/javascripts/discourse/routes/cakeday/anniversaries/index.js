import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class CakedayAnniversariesIndex extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("cakeday.anniversaries.today");
  }
}
