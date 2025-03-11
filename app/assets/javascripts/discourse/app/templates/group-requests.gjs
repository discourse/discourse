{{#if (or this.loading this.canLoadMore)}}
  {{hide-application-footer}}
{{/if}}

<section class="user-content">
  <div class="group-members-actions">
    <TextField
      @value={{this.filterInput}}
      @placeholderKey={{this.filterPlaceholder}}
      class="group-username-filter no-blur"
    />
  </div>

  {{#if this.hasRequesters}}
    <LoadMore
      @selector=".directory-table .directory-table__cell"
      @action={{action "loadMore"}}
    >
      <ResponsiveTable @className="group-members group-members__requests">
        <:header>
          <TableHeaderToggle
            @onToggle={{this.updateOrder}}
            @order={{this.order}}
            @asc={{this.asc}}
            @field="username_lower"
            @labelKey="username"
            @automatic={{true}}
            class="username"
          />
          <TableHeaderToggle
            @onToggle={{this.updateOrder}}
            @order={{this.order}}
            @asc={{this.asc}}
            @field="requested_at"
            @labelKey="groups.member_requested"
            @automatic={{true}}
          />
          <div
            class="directory-table__column-header group-request-reason__column-header"
          >{{i18n "groups.requests.reason"}}</div>
          <div class="directory-table__column-header"></div>
        </:header>
        <:body>
          {{#each this.model.requesters as |m|}}
            <div class="directory-table__row">
              <div class="directory-table__cell group-member">
                <UserInfo @user={{m}} @skipName={{this.skipName}} />
              </div>
              <div class="directory-table__cell">
                <span class="directory-table__label">
                  <span>{{i18n "groups.member_requested"}}</span>
                </span>
                <span class="directory-table__value">
                  <span>{{bound-date m.requested_at}}</span>
                </span>
              </div>
              <div class="directory-table__cell group-request-reason__content">
                <span class="directory-table__label">
                  <span>{{i18n "groups.requests.reason"}}</span>
                </span>
                <span class="directory-table__value">
                  {{m.reason}}
                </span>
              </div>
              <div class="directory-table__cell group-accept-deny-buttons">
                {{#if m.request_undone}}
                  {{i18n "groups.requests.undone"}}
                {{else if m.request_accepted}}
                  {{i18n "groups.requests.accepted"}}
                  <DButton
                    @action={{fn (action "undoAcceptRequest") m}}
                    @label="groups.requests.undo"
                  />
                {{else if m.request_denied}}
                  {{i18n "groups.requests.denied"}}
                {{else}}
                  <DButton
                    @action={{fn (action "acceptRequest") m}}
                    @label="groups.requests.accept"
                    class="btn-primary"
                  />
                  <DButton
                    @action={{fn (action "denyRequest") m}}
                    @label="groups.requests.deny"
                    class="btn-danger"
                  />
                {{/if}}
              </div>
            </div>
          {{/each}}
        </:body>
      </ResponsiveTable>
    </LoadMore>
    <ConditionalLoadingSpinner @condition={{this.loading}} />
  {{else}}
    <div>{{i18n "groups.empty.requests"}}</div>
  {{/if}}
</section>