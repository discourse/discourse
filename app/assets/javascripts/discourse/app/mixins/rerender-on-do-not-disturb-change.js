import Mixin from "@ember/object/mixin";
import { cancel } from "@ember/runloop";
import { isTesting } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";

export default Mixin.create({
  _listenToDoNotDisturbLoop: null,

  listenForDoNotDisturbChanges() {
    if (this.currentUser && !this.currentUser.isInDoNotDisturb()) {
      this.queueRerender();
    } else {
      cancel(this._listenToDoNotDisturbLoop);
      this._listenToDoNotDisturbLoop = discourseLater(
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
