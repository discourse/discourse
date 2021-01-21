import { cancel, later } from "@ember/runloop";
import Mixin from "@ember/object/mixin";
import { isTesting } from "discourse-common/config/environment";

export default Mixin.create({
  _listenToDoNotDisturbLoop: null,

  listenForDoNotDisturbChanges() {
    if (this.currentUser && !this.currentUser.isInDoNotDisturb()) {
      this.queueRerender();
    } else {
      cancel(this._listenToDoNotDisturbLoop);
      this._listenToDoNotDisturbLoop = later(
        this,
        () => {
          this.listenForDoNotDisturbChanges();
        },
        10000
      );
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("do-not-disturb:changed", () => this.queueRerender());
    if (!isTesting()) {
      this.listenForDoNotDisturbChanges();
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    cancel(this._listenToDoNotDisturbLoop);
  },
});
