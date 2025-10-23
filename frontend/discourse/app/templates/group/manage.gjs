import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <section class="user-secondary-navigation">
      <HorizontalOverflowNav class="activity-nav">
        {{#each @controller.tabs as |tab|}}
          <li>
            <LinkTo @route={{tab.route}} @model={{@controller.model.name}}>
              {{i18n tab.title}}
            </LinkTo>
          </li>
        {{/each}}
      </HorizontalOverflowNav>
    </section>
    <section class="user-content" id="user-content">
      {{outlet}}
    </section>
  </template>
);
