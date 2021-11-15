import Evented from "@ember/object/evented";
import Service from "@ember/service";

export default Service.extend(Evented, {
  init() {
    this._super(...arguments);

    // A hack because we don't make `current user` properly via container in testing mode
    if (this.currentUser) {
      this.currentUser.appEvents = this;
    }
  },
});
