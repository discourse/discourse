import Route from "@ember/routing/route";
import ApiKey from "admin/models/api-key";

export default Route.extend({
  model() {
    return ApiKey.find();
  }
});
