{{#if this.model.canLoadMore}}
  {{hide-application-footer}}
{{/if}}

{{body-class "user-notifications-page"}}

<div class="user-navigation user-navigation-secondary">
  <HorizontalOverflowNav @ariaLabel="User secondary - notifications">
    <DNavigationItem
      @route="userNotifications.index"
      @ariaCurrentContext="subNav"
      class="user-nav__notifications-all"
    >
      {{d-icon "bell"}}
      <span>{{i18n "user.filters.all"}}</span>
    </DNavigationItem>

    <DNavigationItem
      @route="userNotifications.responses"
      @ariaCurrentContext="subNav"
      class="user-nav__notifications-responses"
    >
      {{d-icon "reply"}}
      <span>{{i18n "user_action_groups.5"}}</span>
    </DNavigationItem>

    <DNavigationItem
      @route="userNotifications.likesReceived"
      @ariaCurrentContext="subNav"
      class="user-nav__notifications-likes"
    >
      {{d-icon "heart"}}
      <span>{{i18n "user_action_groups.2"}}</span>
    </DNavigationItem>

    {{#if this.siteSettings.enable_mentions}}
      <DNavigationItem
        @route="userNotifications.mentions"
        @ariaCurrentContext="subNav"
        class="user-nav__notifications-mentions"
      >
        {{d-icon "at"}}
        <span>{{i18n "user_action_groups.7"}}</span>
      </DNavigationItem>
    {{/if}}

    <DNavigationItem
      @route="userNotifications.edits"
      @ariaCurrentContext="subNav"
      class="user-nav__notifications-edits"
    >
      {{d-icon "pencil"}}
      <span>{{i18n "user_action_groups.11"}}</span>
    </DNavigationItem>

    <DNavigationItem
      @route="userNotifications.links"
      @ariaCurrentContext="subNav"
      class="user-nav__notifications-links"
    >
      {{d-icon "link"}}
      <span>{{i18n "user_action_groups.17"}}</span>
    </DNavigationItem>

    <PluginOutlet
      @name="user-notifications-bottom"
      @connectorTagName="li"
      @outletArgs={{hash model=this.model}}
    />

  </HorizontalOverflowNav>

  {{#if this.model}}
    <div class="navigation-controls">
      <DButton
        @title="user.dismiss_notifications_tooltip"
        @action={{action "resetNew"}}
        @label="user.dismiss_notifications"
        @icon="check"
        @disabled={{this.allNotificationsRead}}
        class="btn-default dismiss-notifications"
      />
    </div>
  {{/if}}
</div>

<section class="user-content" id="user-content">
  <LoadMore
    @selector=".user-stream .notification"
    @action={{action "loadMore"}}
    class="notification-history user-stream"
  >
    {{outlet}}
    <ConditionalLoadingSpinner @condition={{this.model.loadingMore}} />
  </LoadMore>
</section>