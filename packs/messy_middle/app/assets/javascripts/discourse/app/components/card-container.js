import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import DiscourseURL, { groupPath, userPath } from "discourse/lib/url";

export default class CardWrapper extends Component {
  @service site;
  @controller topic;

  @action
  filterPosts(user) {
    const topicController = this.topic;
    topicController.send("filterParticipant", user);
  }

  @action
  showUser(user) {
    DiscourseURL.routeTo(userPath(user.username_lower));
  }

  @action
  showGroup(group) {
    DiscourseURL.routeTo(groupPath(group.name));
  }
}
