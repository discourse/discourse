import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/application";
import { service } from "@ember/service";

export default class ChatTrackingState {
  @service chatTrackingStateManager;

  @tracked _unreadCount;
  @tracked _mentionCount;

  constructor(owner, params = {}) {
    setOwner(this, owner);
    this._unreadCount = params.unreadCount ?? 0;
    this._mentionCount = params.mentionCount ?? 0;
  }

  reset() {
    this._unreadCount = 0;
    this._mentionCount = 0;
  }

  get unreadCount() {
    return this._unreadCount;
  }

  set unreadCount(value) {
    const valueChanged = this._unreadCount !== value;
    if (valueChanged) {
      this._unreadCount = value;
      this.chatTrackingStateManager.triggerNotificationsChanged();
    }
  }

  get mentionCount() {
    return this._mentionCount;
  }

  set mentionCount(value) {
    const valueChanged = this._mentionCount !== value;
    if (valueChanged) {
      this._mentionCount = value;
      this.chatTrackingStateManager.triggerNotificationsChanged();
    }
  }
}
