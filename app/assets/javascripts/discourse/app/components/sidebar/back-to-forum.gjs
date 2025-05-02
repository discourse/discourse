import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class BackToForum extends Component {
  @service routeHistory;

  get href() {
    const lastNonAdminUrl = this.routeHistory.history.find(
      (url) => !url.startsWith("/admin")
    );
    if (lastNonAdminUrl) {
      return getURL(lastNonAdminUrl);
    }
    return getURL("/");
  }

  <template>
    <a href={{this.href}} class="sidebar-sections__back-to-forum">
      {{icon "arrow-left"}}

      <span>{{i18n "sidebar.back_to_forum"}}</span>
    </a>
  </template>
}
