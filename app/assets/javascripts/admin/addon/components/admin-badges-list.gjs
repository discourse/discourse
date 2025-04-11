import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import BadgeButton from "discourse/components/badge-button";
import { i18n } from "discourse-i18n";

export default class AdminBadgesList extends Component {
  @service router;

  get selectedRoute() {
    const currentRoute = this.router.currentRouteName;

    if (currentRoute === "adminBadges.index") {
      return "adminBadges.show";
    } else {
      return currentRoute;
    }
  }

  <template>
    <div class="content-list">
      <ul class="admin-badge-list">
        {{#each @badges as |badge|}}
          <li class="admin-badge-list-item">
            <LinkTo @route={{this.selectedRoute}} @model={{badge.id}}>
              <BadgeButton @badge={{badge}} />
              {{#if badge.newBadge}}
                <span class="list-badge">{{i18n
                    "filters.new.lower_title"
                  }}</span>
              {{/if}}
            </LinkTo>
          </li>
        {{/each}}
      </ul>
    </div>
    {{outlet}}
  </template>
}
