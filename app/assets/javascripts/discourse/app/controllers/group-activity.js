import Controller from "@ember/controller";
import { service } from "@ember/service";
export default Controller.extend({
  router: service(),
  queryParams: ["category_id"],
});
