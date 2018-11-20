import UnknownRoute from "discourse/routes/unknown";

export default UnknownRoute.extend({
  renderTemplate() {
    this.render("unknown");
  }
});
