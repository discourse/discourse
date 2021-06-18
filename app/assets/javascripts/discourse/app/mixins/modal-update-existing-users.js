import Mixin from "@ember/object/mixin";

export default Mixin.create({
  onShow() {
    this.set("updateExistingUsers", null);
  },

  actions: {
    updateExistingUsers() {
      this.set("updateExistingUsers", true);
      this.send("closeModal");
    },

    cancel() {
      this.set("updateExistingUsers", false);
      this.send("closeModal");
    },
  },
});
