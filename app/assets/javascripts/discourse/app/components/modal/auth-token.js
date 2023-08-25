import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { userPath } from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

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
