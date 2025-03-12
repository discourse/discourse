import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { userPath } from "discourse/lib/url";

export default class AuthTokenComponent extends Component {
  @service currentUser;

  @tracked expanded = false;
  @tracked latestPost = null;

  constructor() {
    super(...arguments);
    this.fetchActivity();
  }

  @action
  async fetchActivity() {
    const posts = await ajax(
      userPath(`${this.currentUser.username_lower}/activity.json`)
    );
    if (posts.length > 0) {
      this.latestPost = posts[0];
    }
  }

  @action
  toggleExpanded(event) {
    event?.preventDefault();
    this.expanded = !this.expanded;
  }
}
