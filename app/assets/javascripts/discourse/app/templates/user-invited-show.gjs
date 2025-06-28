import { fn } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import LoadMore from "discourse/components/load-more";
import TextField from "discourse/components/text-field";
import avatar from "discourse/helpers/avatar";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatDuration from "discourse/helpers/format-duration";
import number from "discourse/helpers/number";
import rawDate from "discourse/helpers/raw-date";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default RouteTemplate(
  <template>
    {{bodyClass "user-invites-page"}}

    {{#if @controller.canInviteToForum}}
      <LoadMore
        @id="user-content"
        @action={{@controller.loadMore}}
        class={{concatClass
          "user-content"
          (if @controller.hasLoadedInitialInvites "--loaded")
        }}
      >
        <section class="user-additional-controls">
          {{#if @controller.showSearch}}
            <div class="user-invite-search">
              <form>
                <TextField
                  @value={{@controller.searchTerm}}
                  @placeholderKey="user.invited.search"
                /></form>
            </div>
          {{/if}}
          <section class="user-invite-buttons">
            <DButton
              @icon="plus"
              @action={{@controller.createInvite}}
              @label="user.invited.create"
              class="btn-default invite-button"
            />
            {{#if @controller.canBulkInvite}}
              {{#if @controller.siteSettings.allow_bulk_invite}}
                {{#if @controller.site.desktopView}}
                  <DButton
                    @icon="upload"
                    @action={{@controller.createInviteCsv}}
                    @label="user.invited.bulk_invite.text"
                    class="btn-default"
                  />
                {{/if}}
              {{/if}}
            {{/if}}
            {{#if @controller.showBulkActionButtons}}
              {{#if @controller.inviteExpired}}
                {{#if @controller.removedAll}}
                  <span class="removed-all">
                    {{i18n "user.invited.removed_all"}}
                  </span>
                {{else}}
                  <DButton
                    @icon="xmark"
                    @action={{@controller.destroyAllExpired}}
                    @label="user.invited.remove_all"
                  />
                {{/if}}
              {{/if}}

              {{#if @controller.invitePending}}
                {{#if @controller.reinvitedAll}}
                  <span class="reinvited-all">
                    <DButton
                      @icon="check"
                      @disabled={{true}}
                      @label="user.invited.reinvited_all"
                    />
                  </span>
                {{else if @controller.hasEmailInvites}}
                  <DButton
                    @icon="arrows-rotate"
                    @action={{@controller.reinviteAll}}
                    @label="user.invited.reinvite_all"
                    class="btn-default"
                  />
                {{/if}}
              {{/if}}
            {{/if}}
          </section>
        </section>
        <section>
          {{#if @controller.model.invites}}
            {{#if @controller.inviteRedeemed}}
              <table class="d-table user-invite-list">
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th class="d-table__header-cell">{{i18n
                        "user.invited.user"
                      }}</th>
                    <th class="d-table__header-cell">{{i18n
                        "user.invited.redeemed_at"
                      }}</th>
                    {{#if @controller.model.can_see_invite_details}}
                      <th class="d-table__header-cell">{{i18n
                          "user.last_seen"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "user.invited.topics_entered"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "user.invited.posts_read_count"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "user.invited.time_read"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "user.invited.days_visited"
                        }}</th>
                      <th class="d-table__header-cell">{{i18n
                          "user.invited.invited_via"
                        }}</th>
                    {{/if}}
                  </tr>
                </thead>
                <tbody class="d-table__body">
                  {{#each @controller.model.invites as |invite|}}
                    <tr class="d-table__row">
                      <td class="d-table__cell --overview">
                        <LinkTo @route="user" @model={{invite.user}}>{{avatar
                            invite.user
                            imageSize="tiny"
                          }}</LinkTo>
                        <LinkTo
                          @route="user"
                          @model={{invite.user}}
                        >{{invite.user.username}}</LinkTo>
                      </td>
                      <td class="d-table__cell --detail">
                        <div class="d-table__mobile-label">
                          {{i18n "user.invited.redeemed_at"}}
                        </div>
                        {{formatDate invite.redeemed_at}}
                      </td>
                      {{#if @controller.model.can_see_invite_details}}
                        <td class="d-table__cell --detail">
                          <div class="d-table__mobile-label">
                            {{i18n "user.last_seen"}}
                          </div>
                          {{formatDate invite.user.last_seen_at}}
                        </td>
                        <td class="d-table__cell --detail">
                          <div class="d-table__mobile-label">
                            {{i18n "user.invited.topics_entered"}}
                          </div>
                          {{number invite.user.topics_entered}}
                        </td>
                        <td class="d-table__cell --detail">
                          <div class="d-table__mobile-label">
                            {{i18n "user.invited.posts_read_count"}}
                          </div>
                          {{number invite.user.posts_read_count}}
                        </td>
                        <td class="d-table__cell --detail">
                          <div class="d-table__mobile-label">
                            {{i18n "user.invited.time_read"}}
                          </div>
                          {{formatDuration invite.user.time_read}}
                        </td>
                        <td class="d-table__cell --detail">
                          <div class="d-table__mobile-label">
                            {{i18n "user.invited.days_visited"}}
                          </div>
                          <div>
                            <span
                              title={{i18n "user.invited.days_visited"}}
                            >{{htmlSafe invite.user.days_visited}}</span>
                            /
                            <span
                              title={{i18n "user.invited.account_age_days"}}
                            >{{htmlSafe invite.user.days_since_created}}</span>
                          </div>
                        </td>
                        <td class="d-table__cell --detail">
                          <div class="d-table__mobile-label">
                            {{i18n "user.invited.invited_via"}}
                          </div>
                          {{htmlSafe invite.invite_source}}
                        </td>
                      {{/if}}
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{else}}
              <table class="d-table user-invite-list">
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th class="d-table__header-cell">{{i18n
                        "user.invited.invited_via"
                      }}</th>
                    <th class="d-table__header-cell">{{i18n
                        "user.invited.sent"
                      }}</th>
                    <th class="d-table__header-cell">{{i18n
                        "user.invited.expires_at"
                      }}</th>
                    <th class="d-table__header-cell"></th>
                  </tr>
                </thead>
                <tbody class="d-table__body">
                  {{#each @controller.model.invites as |invite|}}
                    <tr class="d-table__row">
                      <td class="d-table__cell --overview invite-type">
                        <div class="invite-shortkey">
                          {{#if invite.email}}
                            {{icon "envelope"}}
                            {{invite.email}}
                          {{else}}
                            {{icon "link"}}
                            {{i18n
                              "user.invited.invited_via_link"
                              key=invite.shortKey
                              count=invite.redemption_count
                              max=invite.max_redemptions_allowed
                            }}
                          {{/if}}
                        </div>

                        <div class="invite-details">
                          {{#if invite.description}}
                            <div class="invite-description">
                              {{invite.description}}
                            </div>
                          {{/if}}

                          <div class="invite-groups">
                            {{#each invite.groups as |g|}}
                              <span class="invite-extra">
                                <a
                                  href="/g/{{g.name}}"
                                  class="invite-extra-item-link"
                                >{{icon "users"}}
                                  {{g.name}}
                                </a>
                              </span>
                            {{/each}}
                          </div>

                          {{#if invite.topic}}
                            <span class="invite-extra invite-topic">
                              <a
                                href={{invite.topic.url}}
                                class="invite-extra-item-link"
                              >
                                {{icon "file-lines"}}
                                {{invite.topic.title}}
                              </a>
                            </span>
                          {{/if}}
                        </div>
                      </td>

                      <td class="d-table__cell --detail invite-updated-at">
                        <div class="d-table__mobile-label">
                          {{i18n "user.invited.sent"}}
                        </div>
                        {{formatDate invite.updated_at}}
                      </td>

                      <td class="d-table__cell --detail invite-expires-at">
                        <div class="d-table__mobile-label">
                          {{i18n "user.invited.expires_at"}}
                        </div>
                        {{#if @controller.inviteExpired}}
                          {{rawDate invite.expires_at}}
                        {{else if invite.expired}}
                          {{i18n "user.invited.expired"}}
                        {{else}}
                          {{rawDate invite.expires_at}}
                        {{/if}}
                      </td>

                      {{#if invite.can_delete_invite}}
                        <td class="d-table__cell --controls invite-actions">
                          <div class="d-table__cell-actions">
                            <DButton
                              @label="user.invited.edit"
                              @action={{fn @controller.editInvite invite}}
                              @title="user.invited.edit"
                              class="btn-small edit-invite"
                            />
                            <DMenu
                              @identifier="invites-menu"
                              @title={{i18n "more_options"}}
                              @icon="ellipsis-vertical"
                              @onRegisterApi={{@controller.onRegisterApi}}
                              class="btn-small"
                            >
                              <:content>
                                <DropdownMenu as |dropdown|>
                                  <dropdown.item>
                                    <DButton
                                      @action={{fn
                                        @controller.destroyInvite
                                        invite
                                      }}
                                      @icon="trash-can"
                                      class="btn-transparent btn-danger"
                                      @label={{if
                                        invite.destroyed
                                        "user.invited.removed"
                                        "user.invited.remove"
                                      }}
                                    />
                                  </dropdown.item>
                                </DropdownMenu>
                              </:content>
                            </DMenu>
                          </div>
                        </td>
                      {{/if}}
                    </tr>
                  {{/each}}
                </tbody>
              </table>
            {{/if}}

            <ConditionalLoadingSpinner
              @condition={{@controller.invitesLoading}}
            />
          {{else}}
            <div class="user-invite-none">
              {{#if @controller.canBulkInvite}}
                {{htmlSafe (i18n "user.invited.bulk_invite.none")}}
              {{else}}
                {{i18n "user.invited.none"}}
              {{/if}}
            </div>
          {{/if}}
        </section>
      </LoadMore>
    {{else}}
      <div class="alert alert-error invite-error">
        {{@controller.model.error}}
      </div>
    {{/if}}
  </template>
);
