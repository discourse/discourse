import Upload from "discourse/models/upload";

export default Discourse.Route.extend({
  model() {
    return Upload.findAll();
  },
});
