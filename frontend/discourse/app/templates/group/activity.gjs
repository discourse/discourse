import GroupActivityFilter from "discourse/components/group-activity-filter";
import PluginOutlet from "discourse/components/plugin-outlet";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";

export default <template>
  <section class="user-secondary-navigation">
    <DHorizontalOverflowNav class="activity-nav">
      {{#if @controller.model.can_see_members}}
        <GroupActivityFilter
          @categoryId={{@controller.category_id}}
          @filter="posts"
        />
        <GroupActivityFilter
          @categoryId={{@controller.category_id}}
          @filter="topics"
        />
      {{/if}}
      {{#if @controller.siteSettings.enable_mentions}}
        <GroupActivityFilter
          @categoryId={{@controller.category_id}}
          @filter="mentions"
        />
      {{/if}}
      <PluginOutlet @connectorTagName="li" @name="group-activity-bottom" />
    </DHorizontalOverflowNav>
  </section>
  <section class="user-content" id="user-content">
    {{outlet}}
  </section>
</template>
