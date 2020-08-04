import Service from "@ember/service";
import Presence, {
  CLOSED
} from "discourse/plugins/discourse-presence/discourse/lib/presence";

const PresenceManager = Service.extend({
  presences: null,

  init() {
    this._super(...arguments);

    this.setProperties({
      presences: {}
    });
  },

  subscribe(topicId, type) {
    if (!topicId) return;
    this._getPresence(topicId).subscribe(type);
  },

  unsubscribe(topicId, type) {
    if (!topicId) return;
    const presence = this._getPresence(topicId);

    if (presence.unsubscribe(type)) {
      delete this.presences[topicId];
    }
  },

  users(topicId) {
    if (!topicId) return [];
    return this._getPresence(topicId).users;
  },

  editingUsers(topicId) {
    if (!topicId) return [];
    return this._getPresence(topicId).editingUsers;
  },

  publish(topicId, state, whisper, postId, staffOnly) {
    if (!topicId) return;
    return this._getPresence(topicId).publish(
      state,
      whisper,
      postId,
      staffOnly
    );
  },

  cleanUpPresence(type) {
    Object.keys(this.presences).forEach(key => {
      this.publish(key, CLOSED);
      this.unsubscribe(key, type);
    });
  },

  _getPresence(topicId) {
    if (!this.presences[topicId]) {
      this.presences[topicId] = Presence.create({
        messageBus: this.messageBus,
        siteSettings: this.siteSettings,
        currentUser: this.currentUser,
        topicId
      });
    }

    return this.presences[topicId];
  }
});

export default PresenceManager;
