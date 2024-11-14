import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/**
  A model representing a Topic's details that aren't always present, such as a list of participants.
  When showing topics in lists and such this information should not be required.
**/

export default class TopicDetails extends RestModel {
  @service store;

  @tracked can_delete;
  @tracked can_edit_staff_notes;
  @tracked can_permanently_delete;
  @tracked can_publish_page;
  @tracked created_by;
  @tracked notification_level;

  loaded = false;

  updateFromJson(details) {
    const topic = this.topic;

    if (details.allowed_users) {
      details.allowed_users = details.allowed_users.map((u) =>
        this.store.createRecord("user", u)
      );
    }

    if (details.participants) {
      details.participants = details.participants.map((p) => {
        p.topic = topic;
        return EmberObject.create(p);
      });
    }

    this.setProperties(details);
    this.set("loaded", true);
  }

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
  }

  removeAllowedGroup(group) {
    const groups = this.allowed_groups;
    const name = group.name;

    return ajax("/t/" + this.get("topic.id") + "/remove-allowed-group", {
      type: "PUT",
      data: { name },
    }).then(() => {
      groups.removeObject(groups.findBy("name", name));
    });
  }

  removeAllowedUser(user) {
    const users = this.allowed_users;
    const username = user.get("username");

    return ajax("/t/" + this.get("topic.id") + "/remove-allowed-user", {
      type: "PUT",
      data: { username },
    }).then(() => {
      users.removeObject(users.findBy("username", username));
    });
  }
}
