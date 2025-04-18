import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class BackToForum extends Component {
  @service routeHistory;

  lastForumUrl = this.routeHistory.lastKnownURL;

  get href() {
    const lastUrl = this.lastForumUrl;
    if (lastUrl.startsWith("/admin")) {
      //  the last page was an admin page, and we do not know were to go
      // so we just go to the homepage
      return getURL("/");
    }
    return getURL(lastUrl);
  }

  <template>
    <a href={{this.href}} class="sidebar-sections__back-to-forum">
      {{icon "arrow-left"}}

      <span>{{i18n "sidebar.back_to_forum"}}</span>
    </a>
  </template>
}
