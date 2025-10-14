import Controller from "@ember/controller";

export default class DiscoursePostEventUpcomingEventsMineController extends Controller {
  get initialView() {
    return this.model.view;
  }

  get initialDate() {
    return Date.parse(
      `${this.model.year}/${this.model.month}/${this.model.day}`
    );
  }
}
