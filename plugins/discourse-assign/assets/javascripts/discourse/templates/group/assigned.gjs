import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import MobileNav from "discourse/components/mobile-nav";
import bodyClass from "discourse/helpers/body-class";
import withEventValue from "discourse/helpers/with-event-value";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";
import GroupAssignedFilter from "../../components/group-assigned-filter";

export default <template>
  <section class="user-secondary-navigation group-assignments">
    {{bodyClass "group-assign"}}
    <MobileNav
      class="activity-nav"
      @desktopClass="action-list activity-list nav-stacked"
    >
      {{#if @controller.isDesktop}}
        <div class="search-div">
          <Input
            class="search"
            placeholder={{i18n
              "discourse_assign.sidebar_name_filter_placeholder"
            }}
            @type="text"
            @value={{readonly @controller.filterName}}
            {{on "input" (withEventValue @controller.onChangeFilterName)}}
          />
        </div>
      {{/if}}

      <DLoadMore @action={{@controller.loadMore}} @selector=".activity-nav li">
        <GroupAssignedFilter
          @ascending={{@controller.ascending}}
          @assignmentCount={{@controller.group.assignment_count}}
          @filter="everyone"
          @order={{@controller.order}}
          @routeType={{@controller.route_type}}
          @search={{@controller.search}}
          @showAvatar={{false}}
        />

        <GroupAssignedFilter
          @ascending={{@controller.ascending}}
          @assignmentCount={{@controller.group.group_assignment_count}}
          @filter={{@controller.group.name}}
          @groupName={{@controller.group.name}}
          @order={{@controller.order}}
          @routeType={{@controller.route_type}}
          @search={{@controller.search}}
          @showAvatar={{false}}
        />

        {{#each @controller.members as |member|}}
          <GroupAssignedFilter
            @ascending={{@controller.ascending}}
            @filter={{member}}
            @order={{@controller.order}}
            @routeType={{@controller.route_type}}
            @search={{@controller.search}}
            @showAvatar={{true}}
          />
        {{/each}}

        <DConditionalLoadingSpinner @condition={{@controller.loading}} />
      </DLoadMore>
    </MobileNav>
  </section>

  <section class="user-content">
    {{outlet}}
  </section>
</template>
