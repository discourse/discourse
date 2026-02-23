/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("")
export default class NavItem extends Component {
  static shouldRender(args) {
    return args.group.has_visible_data_explorer_queries;
  }

  <template>
    <li class="group-reports-nav-item-outlet nav-item" ...attributes>
      <LinkTo @route="group.reports">
        {{icon "chart-bar"}}{{i18n "group.reports"}}
      </LinkTo>
    </li>
  </template>
}
