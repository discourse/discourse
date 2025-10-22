import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import EmptyState from "discourse/components/empty-state";
import PluginOutlet from "discourse/components/plugin-outlet";
import MenuItem from "discourse/components/user-menu/menu-item";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import NotificationsFilter from "select-kit/components/notifications-filter";

export default RouteTemplate(
  <template>
    {{#if @controller.model.error}}
      <div class="item error">
        {{#if @controller.model.forbidden}}
          {{i18n "errors.reasons.forbidden"}}
        {{else}}
          {{i18n "errors.desc.unknown"}}
        {{/if}}
      </div>
    {{else if @controller.doesNotHaveNotifications}}
      <PluginOutlet @name="user-notifications-empty-state">
        <EmptyState
          @title={{i18n "user.no_notifications_page_title"}}
          @body={{@controller.emptyStateBody}}
        />
      </PluginOutlet>
    {{else}}
      <PluginOutlet @name="user-notifications-above-filter" />
      <div class="user-notifications-filter">
        <NotificationsFilter
          @value={{@controller.filter}}
          @onChange={{@controller.updateFilter}}
        />
        <PluginOutlet
          @name="user-notifications-after-filter"
          @outletArgs={{lazyHash items=@controller.items}}
        />
      </div>

      {{#if @controller.nothingFound}}
        <div class="alert alert-info">{{i18n "notifications.empty"}}</div>
      {{else}}
        <div class={{@controller.listContainerClassNames}}>
          {{#each @controller.items as |item|}}
            <MenuItem @item={{item}} />
          {{/each}}
          <ConditionalLoadingSpinner @condition={{@controller.loading}} />
          <PluginOutlet
            @name="user-notifications-list-bottom"
            @outletArgs={{lazyHash controller=@controller}}
          />
        </div>
      {{/if}}
    {{/if}}
  </template>
);
