import { cancel, debounce } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";

const PRESENCE_CHANNEL_PREFIX = "/discourse-presence";
const KEEP_ALIVE_DURATION_SECONDS = 10;

export default class ComposerPresenceManager extends Service {
  @service presence;

  notifyState(intent, id) {
    if (
      this.siteSettings.allow_users_to_hide_profile &&
      this.currentUser.user_option.hide_presence
    ) {
      return;
    }

    if (intent === undefined) {
      return this.leave();
    }

    if (!["reply", "whisper", "edit"].includes(intent)) {
      throw `Unknown intent ${intent}`;
    }

    const state = `${intent}/${id}`;

    if (this._state !== state) {
      this._enter(intent, id);
      this._state = state;
    }

    if (!isTesting()) {
      this._autoLeaveTimer = debounce(
        this,
        this.leave,
        KEEP_ALIVE_DURATION_SECONDS * 1000
      );
    }
  }

  leave() {
    this._presentChannel?.leave();
    this._presentChannel = null;
    this._state = null;
    if (this._autoLeaveTimer) {
      cancel(this._autoLeaveTimer);
      this._autoLeaveTimer = null;
    }
  }

  _enter(intent, id) {
    this.leave();

    let channelName = `${PRESENCE_CHANNEL_PREFIX}/${intent}/${id}`;
    this._presentChannel = this.presence.getChannel(channelName);
    this._presentChannel.enter();
  }

  willDestroy() {
    this.leave();
  }
}
