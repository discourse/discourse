import { LinkTo } from "@ember/routing";
import BadgeButton from "discourse/components/badge-button";
import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="content-list">
      <ul class="admin-badge-list">
        {{#each @controller.model as |badge|}}
          <li class="admin-badge-list-item">
            <LinkTo
              @route={{@controller.selectedRoute}}
              @model={{badge.id}}
            >
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
    <section class="current-badge content-body">
      <h2>{{i18n "admin.badges.badge_intro.title"}}</h2>
      <p>{{i18n "admin.badges.badge_intro.description"}}</p>
    </section>
  </template>
);
