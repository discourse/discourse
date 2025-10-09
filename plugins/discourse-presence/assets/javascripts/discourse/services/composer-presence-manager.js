import { cancel, debounce } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { isTesting } from "discourse/lib/environment";

const KEEP_ALIVE = 10 * 1000; // 10 seconds

export default class ComposerPresenceManager extends Service {
  @service currentUser;
  @service presence;

  notifyState(name, replying = true, keepAlive = KEEP_ALIVE) {
    if (!replying) {
      this.leave();
      return;
    }

    if (this.currentUser.user_option.hide_presence) {
      return;
    }

    if (this._name !== name) {
      this.leave();

      this._name = name;
      this._channel = this.presence.getChannel(name);
      this._channel.enter();

      if (!isTesting()) {
        this._autoLeaveTimer = debounce(this, this.leave, keepAlive);
      }
    }
  }

  leave() {
    if (this._autoLeaveTimer) {
      cancel(this._autoLeaveTimer);
      this._autoLeaveTimer = null;
    }

    this._channel?.leave();
    this._channel = null;
    this._name = null;
  }
}
