import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNames("group-reports-nav-item-outlet", "nav-item")
export default class NavItem extends Component {
  static shouldRender(args) {
    return args.group.has_visible_data_explorer_queries;
  }

  <template>
    <LinkTo @route="group.reports">
      {{icon "chart-bar"}}{{i18n "group.reports"}}
    </LinkTo>
  </template>
}
