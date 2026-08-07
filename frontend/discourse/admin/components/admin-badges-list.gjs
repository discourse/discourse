import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBadgeButton from "discourse/ui-kit/d-badge-button";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
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

  get searchableProps() {
    return ["name", "description"];
  }

  <template>
    <div class="content-list">
      <DFilterControls
        @array={{@badges}}
        @searchableProps={{this.searchableProps}}
        @textFilterQueryParam="filter"
        @inputPlaceholder={{i18n "admin.badges.filter_placeholder"}}
        @noResultsMessage={{i18n "admin.badges.no_badges_found"}}
      >
        <:content as |filteredBadges|>
          <ul class="admin-badge-list">
            {{#each filteredBadges as |badge|}}
              <li class="admin-badge-list-item">
                <LinkTo @route={{this.selectedRoute}} @model={{badge.id}}>
                  <DBadgeButton @badge={{badge}} />
                  {{#if badge.newBadge}}
                    <span class="list-badge">{{i18n
                        "filters.new.lower_title"
                      }}</span>
                  {{/if}}
                </LinkTo>
              </li>
            {{/each}}
          </ul>
        </:content>
      </DFilterControls>
    </div>
    {{outlet}}
  </template>
}
