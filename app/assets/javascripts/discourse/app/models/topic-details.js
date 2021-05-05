import EmberObject from "@ember/object";
import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";

/**
  A model representing a Topic's details that aren't always present, such as a list of participants.
  When showing topics in lists and such this information should not be required.
**/

const TopicDetails = RestModel.extend({
  loaded: false,

  updateFromJson(details) {
    const topic = this.topic;

    if (details.allowed_users) {
      details.allowed_users = details.allowed_users.map(function (u) {
        return User.create(u);
      });
    }

    if (details.participants) {
      details.participants = details.participants.map(function (p) {
        p.topic = topic;
        return EmberObject.create(p);
      });
    }

    this.setProperties(details);
    this.set("loaded", true);
  },

  updateNotifications(level) {
    return ajax(`/t/${this.get("topic.id")}/notifications`, {
      type: "POST",
      data: { notification_level: level },
    }).then(() => {
      this.setProperties({
        notification_level: level,
        notifications_reason_id: null,
      });
    });
  },

  removeAllowedGroup(group) {
    const groups = this.allowed_groups;
    const name = group.name;

    return ajax("/t/" + this.get("topic.id") + "/remove-allowed-group", {
      type: "PUT",
      data: { name: name },
    }).then(() => {
      groups.removeObject(groups.findBy("name", name));
    });
  },

  removeAllowedUser(user) {
    const users = this.allowed_users;
    const username = user.get("username");

    return ajax("/t/" + this.get("topic.id") + "/remove-allowed-user", {
      type: "PUT",
      data: { username: username },
    }).then(() => {
      users.removeObject(users.findBy("username", username));
    });
  },
});

export default TopicDetails;
