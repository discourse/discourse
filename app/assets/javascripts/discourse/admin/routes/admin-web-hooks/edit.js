import DiscourseRoute from "discourse/routes/discourse";

export default class AdminWebHooksEditRoute extends DiscourseRoute {
  model(params) {
    return this.store.find("web-hook", params.web_hook_id);
  }
}
