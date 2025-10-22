import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import MobileNav from "discourse/components/mobile-nav";
import bodyClass from "discourse/helpers/body-class";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";
import GroupAssignedFilter from "../../components/group-assigned-filter";

export default RouteTemplate(
  <template>
    <section class="user-secondary-navigation group-assignments">
      {{bodyClass "group-assign"}}
      <MobileNav
        @desktopClass="action-list activity-list nav-stacked"
        class="activity-nav"
      >
        {{#if @controller.isDesktop}}
          <div class="search-div">
            <Input
              {{on "input" (withEventValue @controller.onChangeFilterName)}}
              @type="text"
              @value={{readonly @controller.filterName}}
              placeholder={{i18n
                "discourse_assign.sidebar_name_filter_placeholder"
              }}
              class="search"
            />
          </div>
        {{/if}}

        <LoadMore @selector=".activity-nav li" @action={{@controller.loadMore}}>
          <GroupAssignedFilter
            @showAvatar={{false}}
            @filter="everyone"
            @routeType={{@controller.route_type}}
            @assignmentCount={{@controller.group.assignment_count}}
            @search={{@controller.search}}
            @ascending={{@controller.ascending}}
            @order={{@controller.order}}
          />

          <GroupAssignedFilter
            @showAvatar={{false}}
            @groupName={{@controller.group.name}}
            @filter={{@controller.group.name}}
            @routeType={{@controller.route_type}}
            @assignmentCount={{@controller.group.group_assignment_count}}
            @search={{@controller.search}}
            @ascending={{@controller.ascending}}
            @order={{@controller.order}}
          />

          {{#each @controller.members as |member|}}
            <GroupAssignedFilter
              @showAvatar={{true}}
              @filter={{member}}
              @routeType={{@controller.route_type}}
              @search={{@controller.search}}
              @ascending={{@controller.ascending}}
              @order={{@controller.order}}
            />
          {{/each}}

          <ConditionalLoadingSpinner @condition={{@controller.loading}} />
        </LoadMore>
      </MobileNav>
    </section>

    <section class="user-content">
      {{outlet}}
    </section>
  </template>
);
