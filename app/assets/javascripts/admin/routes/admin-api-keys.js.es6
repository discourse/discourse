import ApiKey from "admin/models/api-key";

export default Ember.Route.extend({
  model() {
    return ApiKey.find();
  }
});
