import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import getURL from "discourse/lib/get-url";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import RouteHistoryService from "discourse/services/route-history";

export default class BackToForum extends Component {
  @service(() => RouteHistoryService) routeHistory;

  get href() {
    if (this.args.href) {
      return this.args.href;
    }

    const lastForumUrl = this.routeHistory.history.find((url) => {
      return !url.startsWith("/admin") && !url.startsWith("/chat");
    });

    if (
      lastForumUrl &&
      this.routeHistory.router.currentURL.startsWith("/admin")
    ) {
      return getURL(lastForumUrl);
    }
    return getURL("/");
  }

  get label() {
    return this.args.label ?? "sidebar.back_to_forum";
  }

  <template>
    <a class="sidebar-sections__back-to-forum" href={{this.href}}>
      {{dIcon "arrow-left"}}

      <span>{{i18n this.label}}</span>
    </a>
  </template>
}
