import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class NavItem extends Component {
  static shouldRender(args) {
    return args.group.has_visible_data_explorer_queries;
  }

  <template>
    <li class="group-reports-nav-item-outlet nav-item" ...attributes>
      <LinkTo @route="group.reports">
        {{dIcon "chart-bar"}}{{i18n "group.reports"}}
      </LinkTo>
    </li>
  </template>
}
