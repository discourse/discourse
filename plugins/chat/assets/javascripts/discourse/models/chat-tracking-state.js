import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";

export default class ChatTrackingState {
  @service chatTrackingStateManager;

  @tracked _unreadCount;
  @tracked _mentionCount;
  @tracked _watchedThreadsUnreadCount;

  constructor(owner, params = {}) {
    setOwner(this, owner);
    this._unreadCount = params.unreadCount ?? 0;
    this._mentionCount = params.mentionCount ?? 0;
    this._watchedThreadsUnreadCount = params.watchedThreadsUnreadCount ?? 0;
  }

  reset() {
    this._unreadCount = 0;
    this._mentionCount = 0;
    this._watchedThreadsUnreadCount = 0;
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

  get watchedThreadsUnreadCount() {
    return this._watchedThreadsUnreadCount;
  }

  set watchedThreadsUnreadCount(value) {
    const valueChanged = this._watchedThreadsUnreadCount !== value;
    if (valueChanged) {
      this._watchedThreadsUnreadCount = value;
      this.chatTrackingStateManager.triggerNotificationsChanged();
    }
  }
}
