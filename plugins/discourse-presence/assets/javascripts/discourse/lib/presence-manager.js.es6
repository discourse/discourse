import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import computed from "discourse-common/utils/decorators";

export const REPLYING = "replying";
export const CLOSED = "closed";

const PresenceManager = EmberObject.extend({
  users: null,
  subscribed: null,
  topic: null,
  currentUser: null,
  messageBus: null,

  init() {
    this._super(...arguments);

    this.setProperties({
      users: [],
      subscribed: false
    });
  },

  subscribe() {
    if (this.get("subscribed")) return;

    this.get("messageBus").subscribe(
      this.get("channel"),
      message => {
        let { user } = message;
        if (this.get("currentUser.id") === user.id) return;
        const { state } = message;

        switch (state) {
          case REPLYING:
            this.get("users").pushObject(user);
            break;
          case CLOSED:
            const users = this.get("users");
            user = users.findBy("id", user.id);
            if (user) this.get("users").removeObject(user);
            break;
        }
      },
      -1
    );

    this.set("subscribed", true);
  },

  unsubscribe() {
    this.get("messageBus").unsubscribe(this.get("channel"));
    this.set("subscribed", false);
  },

  @computed("topic.id")
  channel(topicId) {
    return `/presence/${topicId}`;
  },

  publish(state) {
    return ajax("/presence/publish", {
      type: "POST",
      data: { state, topic_id: this.get("topic.id") }
    });
  }
});

export default PresenceManager;
