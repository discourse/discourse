{{body-class "user-invites-page"}}

{{#if this.canInviteToForum}}
  <LoadMore
    @id="user-content"
    @selector=".user-invite-list tr"
    @action={{action "loadMore"}}
    class="user-content"
  >
    <section class="user-additional-controls">
      {{#if this.showSearch}}
        <div class="user-invite-search">
          <form><TextField
              @value={{this.searchTerm}}
              @placeholderKey="user.invited.search"
            /></form>
        </div>
      {{/if}}
      <section class="user-invite-buttons">
        <DButton
          @icon="plus"
          @action={{this.createInvite}}
          @label="user.invited.create"
          class="btn-default invite-button"
        />
        {{#if this.canBulkInvite}}
          {{#if this.siteSettings.allow_bulk_invite}}
            {{#if this.site.desktopView}}
              <DButton
                @icon="upload"
                @action={{this.createInviteCsv}}
                @label="user.invited.bulk_invite.text"
                class="btn-default"
              />
            {{/if}}
          {{/if}}
        {{/if}}
        {{#if this.showBulkActionButtons}}
          {{#if this.inviteExpired}}
            {{#if this.removedAll}}
              <span class="removed-all">
                {{i18n "user.invited.removed_all"}}
              </span>
            {{else}}
              <DButton
                @icon="xmark"
                @action={{this.destroyAllExpired}}
                @label="user.invited.remove_all"
              />
            {{/if}}
          {{/if}}

          {{#if this.invitePending}}
            {{#if this.reinvitedAll}}
              <span class="reinvited-all">
                <DButton
                  @icon="check"
                  @disabled={{true}}
                  @label="user.invited.reinvited_all"
                />
              </span>
            {{else if this.hasEmailInvites}}
              <DButton
                @icon="arrows-rotate"
                @action={{this.reinviteAll}}
                @label="user.invited.reinvite_all"
                class="btn-default"
              />
            {{/if}}
          {{/if}}
        {{/if}}
      </section>
    </section>
    <section>
      {{#if this.model.invites}}
        {{#if this.inviteRedeemed}}
          <table class="table user-invite-list">
            <thead>
              <tr>
                <th>{{i18n "user.invited.user"}}</th>
                <th>{{i18n "user.invited.redeemed_at"}}</th>
                {{#if this.model.can_see_invite_details}}
                  <th>{{i18n "user.last_seen"}}</th>
                  <th>{{i18n "user.invited.topics_entered"}}</th>
                  <th>{{i18n "user.invited.posts_read_count"}}</th>
                  <th>{{i18n "user.invited.time_read"}}</th>
                  <th>{{i18n "user.invited.days_visited"}}</th>
                  <th>{{i18n "user.invited.invited_via"}}</th>
                {{/if}}
              </tr>
            </thead>
            <tbody>
              {{#each this.model.invites as |invite|}}
                <tr>
                  <td>
                    <LinkTo @route="user" @model={{invite.user}}>{{avatar
                        invite.user
                        imageSize="tiny"
                      }}</LinkTo>
                    <LinkTo
                      @route="user"
                      @model={{invite.user}}
                    >{{invite.user.username}}</LinkTo>
                  </td>
                  <td>{{format-date invite.redeemed_at}}</td>
                  {{#if this.model.can_see_invite_details}}
                    <td>{{format-date invite.user.last_seen_at}}</td>
                    <td>{{number invite.user.topics_entered}}</td>
                    <td>{{number invite.user.posts_read_count}}</td>
                    <td>{{format-duration invite.user.time_read}}</td>
                    <td>
                      <span
                        title={{i18n "user.invited.days_visited"}}
                      >{{html-safe invite.user.days_visited}}</span>
                      /
                      <span
                        title={{i18n "user.invited.account_age_days"}}
                      >{{html-safe invite.user.days_since_created}}</span>
                    </td>
                    <td>{{html-safe invite.invite_source}}</td>
                  {{/if}}
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <table class="table user-invite-list">
            <thead>
              <tr>
                <th>{{i18n "user.invited.invited_via"}}</th>
                <th>{{i18n "user.invited.sent"}}</th>
                <th>{{i18n "user.invited.expires_at"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.model.invites as |invite|}}
                <tr>
                  <td class="invite-type">
                    <div class="label">{{i18n "user.invited.invited_via"}}</div>
                    {{#if invite.email}}
                      {{d-icon "envelope"}}
                      {{invite.email}}
                    {{else}}
                      {{d-icon "link"}}
                      {{i18n
                        "user.invited.invited_via_link"
                        key=invite.shortKey
                        count=invite.redemption_count
                        max=invite.max_redemptions_allowed
                      }}
                    {{/if}}

                    {{#each invite.groups as |g|}}
                      <p class="invite-extra"><a href="/g/{{g.name}}">{{d-icon
                            "users"
                          }}
                          {{g.name}}</a></p>
                    {{/each}}

                    {{#if invite.topic}}
                      <p class="invite-extra"><a
                          href={{invite.topic.url}}
                        >{{d-icon "file"}} {{invite.topic.title}}</a></p>
                    {{/if}}
                  </td>

                  <td class="invite-updated-at">
                    <div class="label">{{i18n "user.invited.sent"}}</div>
                    {{format-date invite.updated_at}}
                  </td>

                  <td class="invite-expires-at">
                    <div class="label">{{i18n "user.invited.expires_at"}}</div>
                    {{#if this.inviteExpired}}
                      {{raw-date invite.expires_at}}
                    {{else if invite.expired}}
                      {{i18n "user.invited.expired"}}
                    {{else}}
                      {{raw-date invite.expires_at}}
                    {{/if}}
                  </td>

                  {{#if invite.can_delete_invite}}
                    <td class="invite-actions">
                      <DButton
                        @icon="pencil"
                        @action={{fn this.editInvite invite}}
                        @title="user.invited.edit"
                        class="btn-default"
                      />
                      <DButton
                        @icon="trash-can"
                        @action={{fn this.destroyInvite invite}}
                        @title={{if
                          invite.destroyed
                          "user.invited.removed"
                          "user.invited.remove"
                        }}
                        class="cancel"
                      />
                    </td>
                  {{/if}}
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}

        <ConditionalLoadingSpinner @condition={{this.invitesLoading}} />
      {{else}}
        <div class="user-invite-none">
          {{#if this.canBulkInvite}}
            {{html-safe (i18n "user.invited.bulk_invite.none")}}
          {{else}}
            {{i18n "user.invited.none"}}
          {{/if}}
        </div>
      {{/if}}
    </section>
  </LoadMore>
{{else}}
  <div class="alert alert-error invite-error">
    {{this.model.error}}
  </div>
{{/if}}