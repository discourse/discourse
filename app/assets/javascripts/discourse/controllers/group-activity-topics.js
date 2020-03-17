import Controller from "@ember/controller";
export default Controller.extend({
  actions: {
    loadMore() {
      this.model.loadMore();
    }
  }
});
