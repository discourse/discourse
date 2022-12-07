import DiscourseRoute from "discourse/routes/discourse";
import StaticPage from "discourse/models/static-page";

export default function (pageName) {
  return DiscourseRoute.extend({
    templateName: "static",

    model() {
      return StaticPage.find(pageName);
    },

    setupController(controller, model) {
      this.controllerFor("static").set("model", model);
    },
  });
}
