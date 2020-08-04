import DiscourseRoute from "discourse/routes/discourse";
import StaticPage from "discourse/models/static-page";

export default function(pageName) {
  const route = {
    model() {
      return StaticPage.find(pageName);
    },

    renderTemplate() {
      this.render("static");
    },

    setupController(controller, model) {
      this.controllerFor("static").set("model", model);
    }
  };
  return DiscourseRoute.extend(route);
}
