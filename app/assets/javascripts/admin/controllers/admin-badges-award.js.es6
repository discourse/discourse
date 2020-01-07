import Controller from "@ember/controller";

export default Controller.extend({
  saving: false,

  actions: {
    massAward() {
      this.set("saving", true);
      setTimeout(() => {
        this.set("saving", false);
      }, 3000);
    }
  }
});
