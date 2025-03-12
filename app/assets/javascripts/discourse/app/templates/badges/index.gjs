import RouteTemplate from "ember-route-template";
import BadgeCard from "discourse/components/badge-card";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{bodyClass "badges-page"}}

    <section>
      <div class="container badges">
        <h1>{{i18n "badges.title"}}</h1>

        <span>
          <PluginOutlet @name="below-badges-title" @connectorTagName="div" />
        </span>

        <div class="badge-groups">
          {{#each @controller.badgeGroups as |bg|}}
            <div class="badge-grouping">
              <div class="title">
                <h2>{{bg.badgeGrouping.displayName}}</h2>
              </div>
              <div class="badge-group-list">
                {{#each bg.badges as |b|}}
                  <BadgeCard
                    @badge={{b}}
                    @username={{@controller.currentUser.username}}
                  />
                {{/each}}
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    </section>
  </template>
);
