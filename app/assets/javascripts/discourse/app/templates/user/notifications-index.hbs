{{#if this.model.error}}
  <div class="item error">
    {{#if this.model.forbidden}}
      {{i18n "errors.reasons.forbidden"}}
    {{else}}
      {{i18n "errors.desc.unknown"}}
    {{/if}}
  </div>
{{else if this.doesNotHaveNotifications}}
  <PluginOutlet @name="user-notifications-empty-state">
    <EmptyState
      @title={{i18n "user.no_notifications_page_title"}}
      @body={{this.emptyStateBody}}
    />
  </PluginOutlet>
{{else}}
  <PluginOutlet @name="user-notifications-above-filter" />
  <div class="user-notifications-filter">
    <NotificationsFilter
      @value={{this.filter}}
      @onChange={{this.updateFilter}}
    />
    <PluginOutlet
      @name="user-notifications-after-filter"
      @outletArgs={{hash items=this.items}}
    />
  </div>

  {{#if this.nothingFound}}
    <div class="alert alert-info">{{i18n "notifications.empty"}}</div>
  {{else}}
    <div class={{this.listContainerClassNames}}>
      {{#each this.items as |item|}}
        <UserMenu::MenuItem @item={{item}} />
      {{/each}}
      <ConditionalLoadingSpinner @condition={{this.loading}} />
      <PluginOutlet
        @name="user-notifications-list-bottom"
        @outletArgs={{hash controller=this}}
      />
    </div>
  {{/if}}
{{/if}}