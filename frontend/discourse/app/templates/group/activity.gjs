import GroupActivityFilter from "discourse/components/group-activity-filter";
import PluginOutlet from "discourse/components/plugin-outlet";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";

export default <template>
  <section class="user-secondary-navigation">
    <DHorizontalOverflowNav class="activity-nav">
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
    </DHorizontalOverflowNav>
  </section>
  <section class="user-content" id="user-content">
    {{outlet}}
  </section>
</template>
