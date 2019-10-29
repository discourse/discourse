import { inject } from '@ember/controller';
import Controller from "@ember/controller";
export default Controller.extend({
  application: inject(),

  _showFooter: function() {
    this.set("application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore")
});
