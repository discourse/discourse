import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { and, gt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatDuration from "discourse/helpers/format-duration";
import htmlSafe from "discourse/helpers/html-safe";
import i18nYesNo from "discourse/helpers/i18n-yes-no";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import AdminEditableField from "admin/components/admin-editable-field";
import AdminUserExportsTable from "admin/components/admin-user-exports-table";
import IpLookup from "admin/components/ip-lookup";
import ComboBox from "select-kit/components/combo-box";
import GroupChooser from "select-kit/components/group-chooser";

export default RouteTemplate(
  <template>
    <section
      class="details {{unless @controller.model.active 'not-activated'}}"
    >
      <div class="user-controls">
        {{#if @controller.model.canViewProfile}}
          <LinkTo
            @route="user"
            @model={{@controller.model}}
            class="btn btn-default"
          >
            {{icon "user"}}
            {{i18n "admin.user.show_public_profile"}}
          </LinkTo>
        {{/if}}

        {{#if @controller.model.can_view_action_logs}}
          <DButton
            @action={{fn @controller.viewActionLogs @controller.model.username}}
            @icon="far-rectangle-list"
            @label="admin.user.action_logs"
            class="btn-default"
          />
        {{/if}}
        {{#if @controller.model.active}}
          {{#if @controller.currentUser.admin}}
            <DButton
              @action={{@controller.logOut}}
              @icon="power-off"
              @label="admin.user.log_out"
              class="btn-default"
            />
          {{/if}}
        {{/if}}
        <PluginOutlet
          @name="admin-user-controls-after"
          @outletArgs={{lazyHash model=@controller.model}}
        />
      </div>

      <div class="display-row username">
        <AdminEditableField
          @name="user.username.title"
          @value={{@controller.model.username}}
          @action={{@controller.saveUsername}}
          @editing={{@controller.editingUsername}}
        />
      </div>

      <div class="display-row name">
        <AdminEditableField
          @name="user.name.title"
          @value={{@controller.model.name}}
          @action={{@controller.saveName}}
          @editing={{@controller.editingName}}
        />
      </div>

      <PluginOutlet
        @name="admin-user-below-names"
        @outletArgs={{lazyHash user=@controller.model}}
      />

      {{#if @controller.canCheckEmails}}
        <div class="display-row email">
          <div class="field">{{i18n "user.email.primary"}}</div>
          <div class="value">
            {{#unless @controller.model.active}}
              <div class="controls">{{i18n "admin.users.not_verified"}}</div>
            {{/unless}}
            {{#if @controller.model.email}}
              <a
                href="mailto:{{@controller.model.email}}"
              >{{@controller.model.email}}</a>
            {{else}}
              <DButton
                @action={{fn (routeAction "checkEmail") @controller.model}}
                @icon="envelope"
                @label="admin.users.check_email.text"
                @title="admin.users.check_email.title"
                class="btn-default"
              />
            {{/if}}
          </div>
          <div class="controls">
            {{#if @controller.siteSettings.auth_overrides_email}}
              {{i18n "user.email.auth_override_instructions"}}
            {{else if @controller.model.email}}
              {{htmlSafe
                (i18n
                  "admin.user.visit_profile" url=@controller.preferencesPath
                )
              }}
            {{/if}}
          </div>
        </div>

        <div class="display-row secondary-emails">
          <div class="field">{{i18n "user.email.secondary"}}</div>

          <div class="value">
            {{#if @controller.model.email}}
              {{#if @controller.model.secondary_emails}}
                <ul>
                  {{#each @controller.model.secondary_emails as |email|}}
                    <li><a href="mailto:{{email}}">{{email}}</a></li>
                  {{/each}}
                </ul>
              {{else}}
                {{i18n "user.email.no_secondary"}}
              {{/if}}
            {{else}}
              <DButton
                @action={{fn (routeAction "checkEmail") @controller.model}}
                @icon="envelope"
                @label="admin.users.check_email.text"
                @title="admin.users.check_email.title"
                class="btn-default"
              />
            {{/if}}
          </div>

          <div class="controls">
            {{#if @controller.model.email}}
              {{#if @controller.model.secondary_emails}}
                {{#if @controller.siteSettings.auth_overrides_email}}
                  {{i18n "user.email.auth_override_instructions"}}
                {{else}}
                  {{htmlSafe
                    (i18n
                      "admin.user.visit_profile" url=@controller.preferencesPath
                    )
                  }}
                {{/if}}
              {{/if}}
            {{/if}}
          </div>
        </div>

        <div class="display-row bounce-score">
          <div class="field"><a href={{@controller.model.bounceLink}}>{{i18n
                "admin.user.bounce_score"
              }}</a></div>
          <div class="value">{{@controller.model.bounceScore}}</div>
          <div class="controls">
            {{#if @controller.model.canResetBounceScore}}
              <DButton
                @action={{@controller.resetBounceScore}}
                @label="admin.user.reset_bounce_score.label"
                @title="admin.user.reset_bounce_score.title"
                class="btn-default"
              />
            {{/if}}
            {{@controller.model.bounceScoreExplanation}}
          </div>
        </div>

        <div class="display-row associations">
          <div class="field">{{i18n "user.associated_accounts.title"}}</div>
          <div class="value">
            {{#if @controller.associatedAccountsLoaded}}
              {{@controller.associatedAccounts}}
            {{else}}
              <DButton
                @action={{fn (routeAction "checkEmail") @controller.model}}
                @icon="envelope"
                @label="admin.users.check_email.text"
                @title="admin.users.check_email.title"
                class="btn-default"
              />
            {{/if}}
          </div>
          {{#if
            (and @controller.currentUser.admin @controller.associatedAccounts)
          }}
            <div class="controls">
              <DButton
                @action={{@controller.deleteAssociatedAccounts}}
                @icon="trash-can"
                @label="admin.users.delete_associated_accounts.text"
                @title="admin.users.delete_associated_accounts.title"
                class="btn-danger"
              />
            </div>
          {{/if}}
        </div>
      {{/if}}

      <div class="display-row">
        <div class="field">{{i18n "user.avatar.title"}}</div>
        <div class="value">{{avatar @controller.model imageSize="large"}}</div>
        <div class="controls">
          {{htmlSafe
            (i18n "admin.user.visit_profile" url=@controller.preferencesPath)
          }}
        </div>
      </div>

      <div class="display-row">
        <AdminEditableField
          @name="user.title.title"
          @value={{@controller.model.title}}
          @action={{@controller.saveTitle}}
          @editing={{@controller.editingTitle}}
        />
      </div>

      <div class="display-row last-ip">
        <div class="field">{{i18n "user.ip_address.title"}}</div>
        <div class="value">{{@controller.model.ip_address}}</div>
        <div class="controls">
          {{#if @controller.currentUser.staff}}
            {{#if @controller.model.ip_address}}
              <IpLookup
                @ip={{@controller.model.ip_address}}
                @userId={{@controller.model.id}}
              />
            {{/if}}
          {{/if}}
        </div>
      </div>

      <div class="display-row registration-ip">
        <div class="field">{{i18n "user.registration_ip_address.title"}}</div>
        <div class="value">{{@controller.model.registration_ip_address}}</div>
        <div class="controls">
          {{#if @controller.currentUser.staff}}
            {{#if @controller.model.registration_ip_address}}
              <IpLookup
                @ip={{@controller.model.registration_ip_address}}
                @userId={{@controller.model.id}}
              />
            {{/if}}
          {{/if}}
        </div>
      </div>

      {{#if @controller.showBadges}}
        <div class="display-row">
          <div class="field">{{i18n "admin.badges.title"}}</div>
          <div class="value">
            {{i18n "badges.badge_count" count=@controller.model.badge_count}}
          </div>
          <div class="controls">
            <LinkTo
              @route="adminUser.badges"
              @model={{@controller.model}}
              class="btn btn-default"
            >
              {{icon "certificate"}}
              {{i18n "admin.badges.edit_badges"}}
            </LinkTo>
          </div>
        </div>
      {{/if}}

      <div class="display-row second-factor">
        <div class="field">{{i18n "user.second_factor.title"}}</div>
        <div class="value">
          {{#if @controller.model.second_factor_enabled}}
            {{i18n "yes_value"}}
          {{else}}
            {{i18n "no_value"}}
          {{/if}}
        </div>
        <div class="controls">
          {{#if @controller.canDisableSecondFactor}}
            <DButton
              @action={{@controller.disableSecondFactor}}
              @icon="unlock-keyhole"
              @label="user.second_factor.disable"
              class="btn-default disable-second-factor"
            />
          {{/if}}
        </div>
      </div>
    </section>

    {{#if @controller.userFields}}
      <section class="details">
        {{#each @controller.userFields as |uf|}}
          <div class="display-row">
            <div class="field">{{uf.name}}</div>
            <div class="value">
              {{#if uf.value}}
                {{uf.value}}
              {{else}}
                &mdash;
              {{/if}}
            </div>
          </div>
        {{/each}}
      </section>
    {{/if}}

    <span>
      <PluginOutlet
        @name="admin-user-details"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <section class="details">
      <h1>{{i18n "admin.user.permissions"}}</h1>

      {{#if @controller.siteSettings.must_approve_users}}
        <div class="display-row">
          <div class="field">{{i18n "admin.users.approved"}}</div>
          <div class="value">
            {{#if @controller.model.approved}}
              {{i18n "admin.user.approved_by"}}
              <LinkTo
                @route="adminUser"
                @model={{@controller.model.approvedBy}}
              >
                {{avatar @controller.model.approvedBy imageSize="small"}}
              </LinkTo>
              <LinkTo
                @route="adminUser"
                @model={{@controller.model.approvedBy}}
              >
                {{@controller.model.approvedBy.username}}
              </LinkTo>
            {{else}}
              {{i18n "no_value"}}
            {{/if}}
          </div>
          <div class="controls">
            {{#if @controller.model.approved}}
              {{i18n "admin.user.approve_success"}}
            {{else}}
              {{#if @controller.model.can_approve}}
                <DButton
                  @action={{@controller.approve}}
                  @icon="check"
                  @label="admin.user.approve"
                  class="btn-default"
                />
              {{/if}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      <div class="display-row">
        <div class="field">{{i18n "admin.users.active"}}</div>
        <div class="value">{{i18nYesNo @controller.model.active}}</div>
        <div class="controls">
          {{#if @controller.model.active}}
            {{#if @controller.model.can_deactivate}}
              <DButton
                @action={{@controller.deactivate}}
                @label="admin.user.deactivate_account"
                class="btn-default"
              />
              {{i18n "admin.user.deactivate_explanation"}}
            {{/if}}
          {{else}}
            {{#if @controller.model.can_send_activation_email}}
              <DButton
                @action={{@controller.sendActivationEmail}}
                @icon="envelope"
                @label="admin.user.send_activation_email"
                class="btn-default"
              />
            {{/if}}
            {{#if @controller.model.can_activate}}
              <DButton
                @action={{@controller.activate}}
                @icon="check"
                @label="admin.user.activate"
                class="btn-default"
              />
            {{/if}}
          {{/if}}
        </div>
      </div>

      <div class="display-row">
        <div class="field">{{i18n "admin.user.staged"}}</div>
        <div class="value">{{i18nYesNo @controller.model.staged}}</div>
        <div class="controls">{{i18n "admin.user.staged_explanation"}}</div>
      </div>

      {{#if @controller.currentUser.admin}}
        <div class="display-row">
          <div class="field">{{i18n "admin.api.active_keys"}}</div>
          <div class="value">
            {{@controller.model.api_key_count}}
          </div>
          <div class="controls">
            <DButton
              @href="/admin/api/keys"
              @label="admin.api.manage_keys"
              class="btn-default"
            />
          </div>
        </div>
      {{/if}}

      <div class="display-row">
        <div class="field">{{i18n "admin.user.admin"}}</div>
        <div class="value">{{i18nYesNo @controller.model.admin}}</div>
        <div class="controls">
          {{#if @controller.model.can_revoke_admin}}
            <DButton
              @action={{@controller.revokeAdmin}}
              @icon="shield-halved"
              @label="admin.user.revoke_admin"
              class="btn-default"
            />
          {{/if}}
          {{#if @controller.model.can_grant_admin}}
            <DButton
              @action={{@controller.grantAdmin}}
              @icon="shield-halved"
              @label="admin.user.grant_admin"
              class="btn-default grant-admin"
            />
          {{/if}}
        </div>
      </div>

      <div class="display-row">
        <div class="field">{{i18n "admin.user.moderator"}}</div>
        <div class="value">{{i18nYesNo @controller.model.moderator}}</div>
        <div class="controls">
          {{#if @controller.model.can_revoke_moderation}}
            <DButton
              @action={{@controller.revokeModeration}}
              @icon="shield-halved"
              @label="admin.user.revoke_moderation"
              class="btn-default"
            />
          {{/if}}
          {{#if @controller.model.can_grant_moderation}}
            <DButton
              @action={{@controller.grantModeration}}
              @icon="shield-halved"
              @label="admin.user.grant_moderation"
              class="btn-default"
            />
          {{/if}}
        </div>
      </div>

      <div class="display-row">
        <div class="field">{{i18n "trust_level"}}</div>
        <div class="value">
          <ComboBox
            @content={{@controller.site.trustLevels}}
            @nameProperty="detailedName"
            @value={{@controller.model.trustLevel.id}}
            @onChange={{fn (mut @controller.model.trust_level)}}
          />

          {{#if @controller.model.dirty}}
            <div>
              <DButton
                @action={{@controller.saveTrustLevel}}
                @icon="check"
                class="ok no-text"
              />
              <DButton
                @action={{@controller.restoreTrustLevel}}
                @icon="xmark"
                class="cancel no-text"
              />
            </div>
          {{/if}}
        </div>
        <div class="controls">
          {{#if @controller.model.canLockTrustLevel}}
            {{#if @controller.hasLockedTrustLevel}}
              {{icon "lock" title="admin.user.trust_level_locked_tip"}}
              <DButton
                @action={{fn @controller.lockTrustLevel false}}
                @label="admin.user.unlock_trust_level"
                class="btn-default"
              />
            {{else}}
              {{icon "unlock" title="admin.user.trust_level_unlocked_tip"}}
              <DButton
                @action={{fn @controller.lockTrustLevel true}}
                @label="admin.user.lock_trust_level"
                class="btn-default"
              />
            {{/if}}
          {{/if}}
          {{#if @controller.model.tl3Requirements}}
            <LinkTo
              @route="adminUser.tl3Requirements"
              @model={{@controller.model}}
              class="btn btn-default"
            >
              {{i18n "admin.user.trust_level_3_requirements"}}
            </LinkTo>
          {{/if}}
        </div>
      </div>

      <div
        class="user-suspended display-row
          {{if @controller.model.suspended 'highlight-danger'}}"
      >
        <div class="field">{{i18n "admin.user.suspended"}}</div>
        <div class="value">
          {{i18nYesNo @controller.model.suspended}}
          {{#if @controller.model.suspended}}
            {{#unless @controller.model.suspendedForever}}
              {{i18n
                "admin.user.suspended_until"
                until=@controller.model.suspendedTillDate
              }}
            {{/unless}}
          {{/if}}
        </div>
        <div class="controls">
          {{#if @controller.model.suspended}}
            <DButton
              @action={{@controller.unsuspend}}
              @icon="ban"
              @label="admin.user.unsuspend"
              class="btn-danger unsuspend-user"
            />
            {{i18n "admin.user.suspended_explanation"}}
          {{else}}
            {{#if @controller.model.canSuspend}}
              <DButton
                @action={{@controller.showSuspendModal}}
                @icon="ban"
                @label="admin.user.suspend"
                class="btn-danger suspend-user"
              />
              {{i18n "admin.user.suspended_explanation"}}
            {{/if}}
          {{/if}}
        </div>
      </div>

      {{#if @controller.model.suspended}}
        <div class="display-row highlight-danger suspension-info">
          <div class="field">{{i18n "admin.user.suspended_by"}}</div>
          <div class="value">
            <LinkTo @route="adminUser" @model={{@controller.model.suspendedBy}}>
              {{avatar @controller.model.suspendedBy imageSize="tiny"}}
            </LinkTo>
            <LinkTo @route="adminUser" @model={{@controller.model.suspendedBy}}>
              {{@controller.model.suspendedBy.username}}
            </LinkTo>
          </div>
          <div class="controls">
            <strong>{{i18n "admin.user.suspend_reason"}}</strong>:
            <div
              class="full-reason"
            >{{@controller.model.full_suspend_reason}}</div>
          </div>
        </div>
      {{/if}}

      <div
        class="display-row {{if @controller.model.silenced 'highlight-danger'}}"
      >
        <div class="field">{{i18n "admin.user.silenced"}}</div>
        <div class="value">
          {{i18nYesNo @controller.model.silenced}}
          {{#if @controller.model.silenced}}
            {{#unless @controller.model.silencedForever}}
              {{i18n
                "admin.user.suspended_until"
                until=@controller.model.silencedTillDate
              }}
            {{/unless}}
          {{/if}}
        </div>
        <div class="controls">
          <ConditionalLoadingSpinner
            @size="small"
            @condition={{@controller.model.silencingUser}}
          >
            {{#if @controller.model.silenced}}
              <DButton
                @action={{@controller.unsilence}}
                @icon="microphone-slash"
                @label="admin.user.unsilence"
                class="btn-danger unsilence-user"
              />
              {{i18n "admin.user.silence_explanation"}}
            {{else}}
              {{#if @controller.model.canSilence}}
                <DButton
                  @action={{@controller.showSilenceModal}}
                  @icon="microphone-slash"
                  @label="admin.user.silence"
                  class="btn-danger silence-user"
                />
                {{i18n "admin.user.silence_explanation"}}
              {{/if}}
            {{/if}}
          </ConditionalLoadingSpinner>
        </div>
      </div>

      {{#if @controller.model.silenced}}
        <div class="display-row highlight-danger silence-info">
          <div class="field">{{i18n "admin.user.silenced_by"}}</div>
          <div class="value">
            <LinkTo @route="adminUser" @model={{@controller.model.silencedBy}}>
              {{avatar @controller.model.silencedBy imageSize="tiny"}}
            </LinkTo>
            <LinkTo @route="adminUser" @model={{@controller.model.silencedBy}}>
              {{@controller.model.silencedBy.username}}
            </LinkTo>
          </div>
          <div class="controls">
            <b>{{i18n "admin.user.silence_reason"}}</b>:
            <div class="full-reason">{{htmlSafe
                @controller.model.silence_reason
              }}</div>
          </div>
        </div>
      {{/if}}

      {{#if @controller.model.tl3_requirements.penalty_counts.total}}
        <div class="display-row clear-penalty-history">
          <div class="field">{{i18n "admin.user.penalty_count"}}</div>
          <div
            class="value"
          >{{@controller.model.tl3_requirements.penalty_counts.total}}</div>
          {{#if @controller.currentUser.admin}}
            <div class="controls">
              <DButton
                @label="admin.user.clear_penalty_history.title"
                @icon="xmark"
                @action={{@controller.clearPenaltyHistory}}
                class="btn-default"
              />
              {{i18n "admin.user.clear_penalty_history.description"}}
            </div>
          {{/if}}
        </div>
      {{/if}}

    </section>

    {{#if @controller.currentUser.admin}}
      <section class="details">
        <h1>{{i18n "admin.groups.title"}}</h1>
        <div class="display-row">
          <div class="field">{{i18n "admin.groups.automatic"}}</div>
          <div class="value">{{htmlSafe @controller.automaticGroups}}</div>
        </div>
        <div class="display-row">
          <div class="field">{{i18n "admin.groups.custom"}}</div>
          <div class="value">
            <GroupChooser
              @content={{@controller.availableGroups}}
              @value={{@controller.customGroupIdsBuffer}}
              @labelProperty="name"
              @onChange={{fn (mut @controller.customGroupIdsBuffer)}}
            />
          </div>
          {{#if @controller.customGroupsDirty}}
            <div class="controls">
              <DButton
                @icon="check"
                @action={{@controller.saveCustomGroups}}
                class="ok"
              />
              <DButton
                @icon="xmark"
                @action={{@controller.resetCustomGroups}}
                class="cancel"
              />
            </div>
          {{/if}}
        </div>
        {{#if @controller.model.customGroups}}
          <div class="display-row">
            <div class="field">{{i18n "admin.groups.primary"}}</div>
            <div class="value">
              <ComboBox
                @content={{@controller.model.customGroups}}
                @value={{@controller.model.primary_group_id}}
                @onChange={{fn (mut @controller.model.primary_group_id)}}
                @options={{hash none="admin.groups.no_primary"}}
              />
            </div>
            {{#if @controller.primaryGroupDirty}}
              <div class="controls">
                <DButton
                  @icon="check"
                  @action={{@controller.savePrimaryGroup}}
                  class="ok"
                />
                <DButton
                  @icon="xmark"
                  @action={{@controller.resetPrimaryGroup}}
                  class="cancel"
                />
              </div>
            {{/if}}
          </div>
        {{/if}}
      </section>
    {{/if}}

    <section class="details">
      <h1>{{i18n "admin.user.activity"}}</h1>

      <div class="display-row">
        <div class="field">{{i18n "created"}}</div>
        <div class="value">{{formatDate
            @controller.model.created_at
            leaveAgo="true"
          }}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.users.last_emailed"}}</div>
        <div class="value">{{formatDate
            @controller.model.last_emailed_at
          }}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "last_seen"}}</div>
        <div class="value">{{formatDate
            @controller.model.last_seen_at
            leaveAgo="true"
          }}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.like_count"}}</div>
        <div class="value">{{@controller.model.like_given_count}}
          /
          {{@controller.model.like_count}}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.topics_entered"}}</div>
        <div class="value">{{@controller.model.topics_entered}}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.post_count"}}</div>
        <div class="value">{{@controller.model.post_count}}</div>
        <div class="controls">
          {{#if @controller.model.can_delete_all_posts}}
            {{#if @controller.model.post_count}}
              <DButton
                @action={{@controller.showDeletePostsConfirmation}}
                @icon="trash-can"
                @label="admin.user.delete_posts.button"
                class="btn-danger"
              />
            {{/if}}
          {{else}}
            {{@controller.deleteAllPostsExplanation}}
          {{/if}}
        </div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.posts_read_count"}}</div>
        <div class="value">{{@controller.model.posts_read_count}}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.warnings_received_count"}}</div>
        <div class="value">{{@controller.model.warnings_received_count}}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n
            "admin.user.flags_given_received_count"
          }}</div>
        <div class="value">
          {{@controller.model.flags_given_count}}
          /
          {{@controller.model.flags_received_count}}
        </div>
        <div class="controls">
          {{#if @controller.model.flags_received_count}}
            <LinkTo
              @route="review"
              @query={{hash
                username=@controller.model.username
                type="ReviewableFlaggedPost"
                status="all"
              }}
              class="btn"
            >
              {{i18n "admin.user.show_flags_received"}}
            </LinkTo>
          {{/if}}
        </div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.private_topics_count"}}</div>
        <div class="value">{{@controller.model.private_topics_count}}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "admin.user.time_read"}}</div>
        <div class="value">{{formatDuration @controller.model.time_read}}</div>
      </div>
      <div class="display-row">
        <div class="field">{{i18n "user.invited.days_visited"}}</div>
        <div class="value">{{htmlSafe @controller.model.days_visited}}</div>
      </div>
      <div class="display-row post-edits-count">
        <div class="field">{{i18n "admin.user.post_edits_count"}}</div>
        <div class="value">
          {{if
            (gt @controller.model.post_edits_count 0)
            @controller.model.post_edits_count
            "0"
          }}
        </div>
        <div class="controls">
          {{#if (gt @controller.model.post_edits_count 0)}}
            <LinkTo
              @route="adminReports.show"
              @model="post_edits"
              @query={{hash filters=@controller.postEditsByEditorFilter}}
              class="btn btn-icon"
            >
              {{icon "far-eye"}}
              {{i18n "admin.user.view_edits"}}
            </LinkTo>
          {{/if}}
        </div>
      </div>
    </section>

    {{#if @controller.model.single_sign_on_record}}
      <section class="details">
        <h1>{{i18n "admin.user.discourse_connect.title"}}</h1>

        {{#let @controller.model.single_sign_on_record as |sso|}}
          <div class="display-row">
            <div class="field">{{i18n
                "admin.user.discourse_connect.external_id"
              }}</div>
            <div class="value">{{sso.external_id}}</div>
            {{#if @controller.model.can_delete_sso_record}}
              <div class="controls">
                <DButton
                  @action={{@controller.deleteSSORecord}}
                  @icon="trash-can"
                  @label="admin.user.discourse_connect.delete_sso_record"
                  class="btn-danger"
                />
              </div>
            {{/if}}
          </div>
          <div class="display-row">
            <div class="field">{{i18n
                "admin.user.discourse_connect.external_username"
              }}</div>
            <div class="value">{{sso.external_username}}</div>
          </div>
          <div class="display-row">
            <div class="field">{{i18n
                "admin.user.discourse_connect.external_name"
              }}</div>
            <div class="value">{{sso.external_name}}</div>
          </div>
          {{#if @controller.canAdminCheckEmails}}
            <div class="display-row">
              <div class="field">{{i18n
                  "admin.user.discourse_connect.external_email"
                }}</div>
              {{#if @controller.ssoExternalEmail}}
                <div class="value">{{@controller.ssoExternalEmail}}</div>
              {{else}}
                <DButton
                  @action={{fn @controller.checkSsoEmail @controller.model}}
                  @icon="envelope"
                  @label="admin.users.check_email.text"
                  @title="admin.users.check_email.title"
                  class="btn-default"
                />
              {{/if}}
            </div>
          {{/if}}
          <div class="display-row">
            <div class="field">{{i18n
                "admin.user.discourse_connect.external_avatar_url"
              }}</div>
            <div class="value">{{sso.external_avatar_url}}</div>
          </div>
          {{#if @controller.canAdminCheckEmails}}
            <div class="display-row">
              <div class="field">{{i18n
                  "admin.user.discourse_connect.last_payload"
                }}</div>
              {{#if @controller.ssoLastPayload}}
                <div class="value">
                  {{#each @controller.ssoPayload as |line|}}
                    {{line}}<br />
                  {{/each}}
                </div>
              {{else}}
                <DButton
                  @action={{fn @controller.checkSsoPayload @controller.model}}
                  @icon="far-rectangle-list"
                  @label="admin.users.check_sso.text"
                  @title="admin.users.check_sso.title"
                  class="btn-default"
                />
              {{/if}}
            </div>
          {{/if}}
        {{/let}}
      </section>
    {{/if}}

    {{#if @controller.currentUser.admin}}
      <AdminUserExportsTable @model={{@controller.model}} />
    {{/if}}

    <span>
      <PluginOutlet
        @name="after-user-details"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <section>
      <hr />
      <div class="pull-right">
        {{#if @controller.model.active}}
          {{#if @controller.model.can_impersonate}}
            <DButton
              @action={{@controller.impersonate}}
              @icon="crosshairs"
              @label="admin.impersonate.title"
              @title="admin.impersonate.help"
              class="btn-danger btn-impersonate"
            />
          {{/if}}
        {{/if}}

        {{#if @controller.model.can_be_anonymized}}
          <DButton
            @label="admin.user.anonymize"
            @icon="triangle-exclamation"
            @action={{@controller.anonymize}}
            class="btn-danger btn-anonymize"
          />
        {{/if}}

        {{#if @controller.model.canBeDeleted}}
          <DButton
            @label="admin.user.delete"
            @icon="trash-can"
            @action={{@controller.destroyUser}}
            class="btn-danger btn-user-delete"
          />
        {{/if}}

        {{#if @controller.model.can_be_merged}}
          <DButton
            @label="admin.user.merge.button"
            @icon="left-right"
            @action={{@controller.promptTargetUser}}
            class="btn-danger btn-user-merge"
          />
        {{/if}}
      </div>

      {{#if @controller.deleteExplanation}}
        <div class="clearfix"></div>
        <br />
        <div class="pull-right">
          {{icon "triangle-exclamation"}}
          {{@controller.deleteExplanation}}
        </div>
      {{/if}}
    </section>

    <div class="clearfix"></div>
  </template>
);
