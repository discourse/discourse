import { concat } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import MenuItem from "discourse/components/user-menu/menu-item";
import lazyHash from "discourse/helpers/lazy-hash";
import NotificationsFilter from "discourse/select-kit/components/notifications-filter";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default <template>
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
      <DEmptyState
        @body={{@controller.emptyStateBody}}
        @title={{i18n "user.no_notifications_page_title"}}
      />
    </PluginOutlet>
  {{else}}
    <PluginOutlet @name="user-notifications-above-filter" />
    <div class="user-notifications-filter">
      <NotificationsFilter
        @onChange={{@controller.updateFilter}}
        @value={{@controller.filter}}
      />
      {{#if @controller.siteSettings.enable_notification_history_type_filter}}
        <DNativeSelect
          aria-label={{i18n "user.user_notifications.type_filters.label"}}
          class="user-notifications-type-filter"
          @nonePlaceholder={{i18n "user.user_notifications.type_filters.all"}}
          @onChange={{@controller.updateNotificationType}}
          @value={{@controller.typeFilterValue}}
          as |select|
        >
          {{#each @controller.notificationTypeOptions as |group|}}
            <select.Option @value={{group}}>
              {{i18n (concat "user.user_notifications.type_filters." group)}}
            </select.Option>
          {{/each}}
        </DNativeSelect>
      {{/if}}
      <PluginOutlet
        @name="user-notifications-after-filter"
        @outletArgs={{lazyHash items=@controller.items}}
      />
    </div>

    {{#if @controller.nothingFound}}
      <div class="alert alert-info">{{i18n "notifications.empty"}}</div>
    {{else}}
      <div
        class={{dConcatClass
          "user-notifications-list"
          (if @controller.siteSettings.show_user_menu_avatars "show-avatars")
        }}
      >
        {{#each @controller.items as |item|}}
          <MenuItem @item={{item}} />
        {{/each}}
        <DConditionalLoadingSpinner @condition={{@controller.loading}} />
        <PluginOutlet
          @name="user-notifications-list-bottom"
          @outletArgs={{lazyHash controller=@controller}}
        />
      </div>
    {{/if}}
  {{/if}}
</template>
