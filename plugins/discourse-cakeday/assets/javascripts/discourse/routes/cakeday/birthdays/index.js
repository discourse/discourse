import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class CakedayBirthdaysIndex extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith("cakeday.birthdays.today");
  }
}
