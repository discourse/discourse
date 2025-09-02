import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class DiscoursePostEventUpcomingEventsIndexController extends Controller {
  @service router;

  get initialView() {
    return this.model.view;
  }

  get initialDate() {
    return Date.parse(
      `${this.model.year}/${this.model.month}/${this.model.day}`
    );
  }
}
