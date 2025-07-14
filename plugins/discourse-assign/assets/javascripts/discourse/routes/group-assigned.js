import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class GroupAssigned extends DiscourseRoute {
  @service router;

  model() {
    return ajax(`/assign/members/${this.modelFor("group").name}`);
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      members: [],
      group: this.modelFor("group"),
    });
    controller.group.setProperties({
      assignment_count: model.assignment_count,
      group_assignment_count: model.group_assignment_count,
    });

    controller.findMembers(true);
  }

  redirect(model, transition) {
    if (!transition.to.params.hasOwnProperty("filter")) {
      this.router.transitionTo("group.assigned.show", "everyone");
    }
  }
}
