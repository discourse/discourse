import RouteTemplate from "ember-route-template";
import GroupActivityFilter from "discourse/components/group-activity-filter";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import PluginOutlet from "discourse/components/plugin-outlet";

export default RouteTemplate(
  <template>
    <section class="user-secondary-navigation">
      <HorizontalOverflowNav class="activity-nav">
        {{#if @controller.model.can_see_members}}
          <GroupActivityFilter
            @filter="posts"
            @categoryId={{@controller.category_id}}
          />
          <GroupActivityFilter
            @filter="topics"
            @categoryId={{@controller.category_id}}
          />
        {{/if}}
        {{#if @controller.siteSettings.enable_mentions}}
          <GroupActivityFilter
            @filter="mentions"
            @categoryId={{@controller.category_id}}
          />
        {{/if}}
        <PluginOutlet @name="group-activity-bottom" @connectorTagName="li" />
      </HorizontalOverflowNav>
    </section>
    <section class="user-content" id="user-content">
      {{outlet}}
    </section>
  </template>
);
