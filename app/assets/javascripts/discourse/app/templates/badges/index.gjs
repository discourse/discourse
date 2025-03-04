import RouteTemplate from 'ember-route-template'
import bodyClass from "discourse/helpers/body-class";
import iN from "discourse/helpers/i18n";
import PluginOutlet from "discourse/components/plugin-outlet";
import BadgeCard from "discourse/components/badge-card";
export default RouteTemplate(<template>{{bodyClass "badges-page"}}

<section>
  <div class="container badges">
    <h1>{{iN "badges.title"}}</h1>

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
              <BadgeCard @badge={{b}} @username={{@controller.currentUser.username}} />
            {{/each}}
          </div>
        </div>
      {{/each}}
    </div>
  </div>
</section></template>)