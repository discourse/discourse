import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import AdminEditableField from "discourse/admin/components/admin-editable-field";
import AdminUserExportsTable from "discourse/admin/components/admin-user-exports-table";
import IpLookup from "discourse/admin/components/ip-lookup";
import PluginOutlet from "discourse/components/plugin-outlet";
import i18nYesNo from "discourse/helpers/i18n-yes-no";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import getURL from "discourse/lib/get-url";
import ComboBox from "discourse/select-kit/components/combo-box";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { and, gt, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="details {{unless @controller.model.active 'not-activated'}}">
    <div class="user-controls">
      {{#if @controller.model.canViewProfile}}
        <LinkTo
          class="btn btn-default"
          @model={{@controller.model}}
          @route="user"
        >
          {{dIcon "user"}}
          {{i18n "admin.user.show_public_profile"}}
        </LinkTo>
      {{/if}}

      {{#if @controller.model.can_view_action_logs}}
        <DButton
          class="btn-default"
          @action={{fn @controller.viewActionLogs @controller.model.username}}
          @icon="far-rectangle-list"
          @label="admin.user.action_logs"
        />
      {{/if}}
      {{#if @controller.model.active}}
        {{#if @controller.currentUser.admin}}
          <DButton
            class="btn-default"
            @action={{@controller.logOut}}
            @icon="power-off"
            @label="admin.user.log_out"
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
        @action={{@controller.saveUsername}}
        @editing={{@controller.editingUsername}}
        @name="user.username.title"
        @value={{@controller.model.username}}
      />
    </div>

    <div class="display-row name">
      <AdminEditableField
        @action={{@controller.saveName}}
        @editing={{@controller.editingName}}
        @name="user.name.title"
        @value={{@controller.model.name}}
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
              class="btn-default"
              @action={{fn (routeAction "checkEmail") @controller.model}}
              @icon="envelope"
              @label="admin.users.check_email.text"
              @title="admin.users.check_email.title"
            />
          {{/if}}
        </div>
        <div class="controls">
          {{#if @controller.siteSettings.auth_overrides_email}}
            {{i18n "user.email.auth_override_instructions"}}
          {{else if @controller.model.email}}
            {{trustHTML
              (i18n "admin.user.visit_profile" url=@controller.preferencesPath)
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
              class="btn-default"
              @action={{fn (routeAction "checkEmail") @controller.model}}
              @icon="envelope"
              @label="admin.users.check_email.text"
              @title="admin.users.check_email.title"
            />
          {{/if}}
        </div>

        <div class="controls">
          {{#if @controller.model.email}}
            {{#if @controller.model.secondary_emails}}
              {{#if @controller.siteSettings.auth_overrides_email}}
                {{i18n "user.email.auth_override_instructions"}}
              {{else}}
                {{trustHTML
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
              class="btn-default"
              @action={{@controller.resetBounceScore}}
              @label="admin.user.reset_bounce_score.label"
              @title="admin.user.reset_bounce_score.title"
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
              class="btn-default"
              @action={{fn (routeAction "checkEmail") @controller.model}}
              @icon="envelope"
              @label="admin.users.check_email.text"
              @title="admin.users.check_email.title"
            />
          {{/if}}
        </div>
        {{#if
          (and @controller.currentUser.admin @controller.associatedAccounts)
        }}
          <div class="controls">
            <DButton
              class="btn-danger"
              @action={{@controller.deleteAssociatedAccounts}}
              @icon="trash-can"
              @label="admin.users.delete_associated_accounts.text"
              @title="admin.users.delete_associated_accounts.title"
            />
          </div>
        {{/if}}
      </div>
    {{/if}}

    <div class="display-row">
      <div class="field">{{i18n "user.avatar.title"}}</div>
      <div class="value">{{dAvatar @controller.model imageSize="large"}}</div>
      <div class="controls">
        {{trustHTML
          (i18n "admin.user.visit_profile" url=@controller.preferencesPath)
        }}
      </div>
    </div>

    <div class="display-row">
      <AdminEditableField
        @action={{@controller.saveTitle}}
        @editing={{@controller.editingTitle}}
        @name="user.title.title"
        @value={{@controller.model.title}}
      />
    </div>

    {{#if @controller.model.include_ip}}
      <div class="display-row last-ip">
        <div class="field">{{i18n "user.ip_address.title"}}</div>
        <div class="value">{{@controller.model.ip_address}}</div>
        <div class="controls">
          {{#if @controller.currentUser.can_see_ip}}
            {{#if @controller.model.ip_address}}
              <IpLookup
                @ip={{@controller.model.ip_address}}
                @ipType="last"
                @userId={{@controller.model.id}}
              />
            {{/if}}
          {{/if}}
        </div>
      </div>
    {{/if}}

    {{#if @controller.model.include_ip}}
      <div class="display-row registration-ip">
        <div class="field">{{i18n "user.registration_ip_address.title"}}</div>
        <div class="value">{{@controller.model.registration_ip_address}}</div>
        <div class="controls">
          {{#if @controller.currentUser.can_see_ip}}
            {{#if @controller.model.registration_ip_address}}
              <IpLookup
                @ip={{@controller.model.registration_ip_address}}
                @ipType="registration"
                @userId={{@controller.model.id}}
              />
            {{/if}}
          {{/if}}
        </div>
      </div>
    {{/if}}

    {{#if @controller.showBadges}}
      <div class="display-row">
        <div class="field">{{i18n "admin.badges.title"}}</div>
        <div class="value">
          {{i18n "badges.badge_count" count=@controller.model.badge_count}}
        </div>
        <div class="controls">
          <LinkTo
            class="btn btn-default"
            @model={{@controller.model}}
            @route="adminUser.badges"
          >
            {{dIcon "certificate"}}
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
            class="btn-default disable-second-factor"
            @action={{@controller.disableSecondFactor}}
            @icon="unlock-keyhole"
            @label="user.second_factor.disable"
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
      @connectorTagName="div"
      @name="admin-user-details"
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
            <LinkTo @model={{@controller.model.approvedBy}} @route="adminUser">
              {{dAvatar @controller.model.approvedBy imageSize="small"}}
            </LinkTo>
            <LinkTo @model={{@controller.model.approvedBy}} @route="adminUser">
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
                class="btn-default"
                @action={{@controller.approve}}
                @icon="check"
                @label="admin.user.approve"
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
              class="btn-default"
              @action={{@controller.deactivate}}
              @label="admin.user.deactivate_account"
            />
            {{i18n "admin.user.deactivate_explanation"}}
          {{/if}}
        {{else}}
          {{#if @controller.model.can_send_activation_email}}
            <DButton
              class="btn-default"
              @action={{@controller.sendActivationEmail}}
              @icon="envelope"
              @label="admin.user.send_activation_email"
            />
          {{/if}}
          {{#if @controller.model.can_activate}}
            <DButton
              class="btn-default"
              @action={{@controller.activate}}
              @icon="check"
              @label="admin.user.activate"
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
            class="btn-default"
            @href={{getURL "/admin/api/keys"}}
            @label="admin.api.manage_keys"
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
            class="btn-default"
            @action={{@controller.revokeAdmin}}
            @icon="shield-halved"
            @label="admin.user.revoke_admin"
          />
        {{/if}}
        {{#if @controller.model.can_grant_admin}}
          <DButton
            class="btn-default grant-admin"
            @action={{@controller.grantAdmin}}
            @icon="shield-halved"
            @label="admin.user.grant_admin"
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
            class="btn-default"
            @action={{@controller.revokeModeration}}
            @icon="shield-halved"
            @label="admin.user.revoke_moderation"
          />
        {{/if}}
        {{#if @controller.model.can_grant_moderation}}
          <DButton
            class="btn-default"
            @action={{@controller.grantModeration}}
            @icon="shield-halved"
            @label="admin.user.grant_moderation"
          />
        {{/if}}
      </div>
    </div>

    <div class="display-row">
      <div class="field">{{i18n "trust_level"}}</div>
      <div class="value">
        <ComboBox
          class="change-trust-level-dropdown"
          @content={{@controller.site.trustLevels}}
          @nameProperty="detailedName"
          @onChange={{fn (mut @controller.model.trust_level)}}
          @options={{hash
            disabled=(not @controller.model.can_change_trust_level)
          }}
          @value={{@controller.model.trustLevel.id}}
        />

        {{#if @controller.model.dirty}}
          <div>
            <DButton
              class="ok no-text"
              @action={{@controller.saveTrustLevel}}
              @icon="check"
            />
            <DButton
              class="cancel no-text"
              @action={{@controller.restoreTrustLevel}}
              @icon="xmark"
            />
          </div>
        {{/if}}
      </div>
      <div class="controls">
        {{#if @controller.model.can_change_trust_level}}
          {{#if @controller.model.canLockTrustLevel}}
            {{#if @controller.hasLockedTrustLevel}}
              {{dIcon "lock" title="admin.user.trust_level_locked_tip"}}
              <DButton
                class="btn-default"
                @action={{fn @controller.lockTrustLevel false}}
                @label="admin.user.unlock_trust_level"
              />
            {{else}}
              {{dIcon "unlock" title="admin.user.trust_level_unlocked_tip"}}
              <DButton
                class="btn-default"
                @action={{fn @controller.lockTrustLevel true}}
                @label="admin.user.lock_trust_level"
              />
            {{/if}}
          {{/if}}
          {{#if @controller.model.tl3Requirements}}
            <LinkTo
              class="btn btn-default"
              @model={{@controller.model}}
              @route="adminUser.tl3Requirements"
            >
              {{i18n "admin.user.trust_level_3_requirements"}}
            </LinkTo>
          {{/if}}
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
            class="btn-danger unsuspend-user"
            @action={{@controller.unsuspend}}
            @icon="ban"
            @label="admin.user.unsuspend"
          />
          {{i18n "admin.user.suspended_explanation"}}
        {{else}}
          {{#if @controller.model.canSuspend}}
            <DButton
              class="btn-danger suspend-user"
              @action={{@controller.showSuspendModal}}
              @icon="ban"
              @label="admin.user.suspend"
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
          <LinkTo @model={{@controller.model.suspendedBy}} @route="adminUser">
            {{dAvatar @controller.model.suspendedBy imageSize="tiny"}}
          </LinkTo>
          <LinkTo @model={{@controller.model.suspendedBy}} @route="adminUser">
            {{@controller.model.suspendedBy.username}}
          </LinkTo>
        </div>
        <div class="controls">
          <strong>{{i18n "admin.user.suspend_reason"}}</strong>:
          <div class="full-reason">{{trustHTML
              @controller.model.full_suspend_reason
            }}</div>
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
        <DConditionalLoadingSpinner
          @condition={{@controller.model.silencingUser}}
          @size="small"
        >
          {{#if @controller.model.silenced}}
            <DButton
              class="btn-danger unsilence-user"
              @action={{@controller.unsilence}}
              @icon="microphone-slash"
              @label="admin.user.unsilence"
            />
            {{i18n "admin.user.silence_explanation"}}
          {{else}}
            {{#if @controller.model.canSilence}}
              <DButton
                class="btn-danger silence-user"
                @action={{@controller.showSilenceModal}}
                @icon="microphone-slash"
                @label="admin.user.silence"
              />
              {{i18n "admin.user.silence_explanation"}}
            {{/if}}
          {{/if}}
        </DConditionalLoadingSpinner>
      </div>
    </div>

    {{#if @controller.model.silenced}}
      <div class="display-row highlight-danger silence-info">
        <div class="field">{{i18n "admin.user.silenced_by"}}</div>
        <div class="value">
          <LinkTo @model={{@controller.model.silencedBy}} @route="adminUser">
            {{dAvatar @controller.model.silencedBy imageSize="tiny"}}
          </LinkTo>
          <LinkTo @model={{@controller.model.silencedBy}} @route="adminUser">
            {{@controller.model.silencedBy.username}}
          </LinkTo>
        </div>
        <div class="controls">
          <b>{{i18n "admin.user.silence_reason"}}</b>:
          <div class="full-reason">{{trustHTML
              @controller.model.full_silence_reason
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
              class="btn-default"
              @action={{@controller.clearPenaltyHistory}}
              @icon="xmark"
              @label="admin.user.clear_penalty_history.title"
            />
            {{i18n "admin.user.clear_penalty_history.description"}}
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if
      (and
        @controller.currentUser.staff @controller.model.upcoming_changes_stats
      )
    }}
      <div class="display-row upcoming-changes-info">
        <div class="field">{{i18n "admin.user.upcoming_changes.title"}}</div>
        <div class="value">
          <DButton
            class="btn-default"
            @action={{@controller.openUserUpcomingChanges}}
            @icon="eye"
            @label="admin.user.upcoming_changes.view_modal"
          />
        </div>
        <div class="controls">
          &nbsp;
        </div>
      </div>
    {{/if}}

  </section>

  {{#if @controller.currentUser.admin}}
    <section class="details">
      <h1>{{i18n "admin.groups.title"}}</h1>
      <div class="display-row admin-user__automatic-groups">
        <div class="field">{{i18n "admin.groups.automatic"}}</div>
        <div class="value">{{trustHTML @controller.automaticGroups}}</div>
      </div>
      <div class="display-row admin-user__custom-groups">
        <div class="field">{{i18n "admin.groups.custom"}}</div>
        <div class="value">
          <GroupChooser
            @content={{@controller.availableGroups}}
            @labelProperty="name"
            @onChange={{fn (mut @controller.customGroupIdsBuffer)}}
            @value={{@controller.customGroupIdsBuffer}}
          />
        </div>
        {{#if @controller.customGroupsDirty}}
          <div class="controls">
            <DButton
              class="ok"
              @action={{@controller.saveCustomGroups}}
              @icon="check"
            />
            <DButton
              class="cancel"
              @action={{@controller.resetCustomGroups}}
              @icon="xmark"
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
              @onChange={{fn (mut @controller.model.primary_group_id)}}
              @options={{hash none="admin.groups.no_primary"}}
              @value={{@controller.model.primary_group_id}}
            />
          </div>
          {{#if @controller.primaryGroupDirty}}
            <div class="controls">
              <DButton
                class="ok"
                @action={{@controller.savePrimaryGroup}}
                @icon="check"
              />
              <DButton
                class="cancel"
                @action={{@controller.resetPrimaryGroup}}
                @icon="xmark"
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
      <div class="value">{{dFormatDate
          @controller.model.created_at
          leaveAgo="true"
        }}</div>
    </div>
    <div class="display-row">
      <div class="field">{{i18n "admin.users.last_emailed"}}</div>
      <div class="value">{{dFormatDate @controller.model.last_emailed_at}}</div>
    </div>
    <div class="display-row">
      <div class="field">{{i18n "last_seen"}}</div>
      <div class="value">{{dFormatDate
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
              class="btn-danger"
              @action={{@controller.showDeletePostsConfirmation}}
              @icon="trash-can"
              @label="admin.user.delete_posts.button"
            />
          {{/if}}
        {{else}}
          {{#if @controller.deleteAllPostsExplanation}}
            <span class="delete-all-posts-explanation">
              {{@controller.deleteAllPostsExplanation}}
            </span>
          {{/if}}
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
      <div class="field">{{i18n "admin.user.flags_given_received_count"}}</div>
      <div class="value">
        {{@controller.model.flags_given_count}}
        /
        {{@controller.model.flags_received_count}}
      </div>
      <div class="controls">
        {{#if @controller.model.flags_received_count}}
          <LinkTo
            class="btn btn-default"
            @query={{hash
              username=@controller.model.username
              type="ReviewableFlaggedPost"
              status="all"
            }}
            @route="review"
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
      <div class="value">{{dFormatDuration @controller.model.time_read}}</div>
    </div>
    <div class="display-row">
      <div class="field">{{i18n "user.invited.days_visited"}}</div>
      <div class="value">{{trustHTML @controller.model.days_visited}}</div>
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
            class="btn btn-icon btn-default"
            @model="post_edits"
            @query={{hash filters=@controller.postEditsByEditorFilter}}
            @route="adminReports.show"
          >
            {{dIcon "far-eye"}}
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
                class="btn-danger"
                @action={{@controller.deleteSSORecord}}
                @icon="trash-can"
                @label="admin.user.discourse_connect.delete_sso_record"
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
                class="btn-default"
                @action={{fn @controller.checkSsoEmail @controller.model}}
                @icon="envelope"
                @label="admin.users.check_email.text"
                @title="admin.users.check_email.title"
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
                class="btn-default"
                @action={{fn @controller.checkSsoPayload @controller.model}}
                @icon="far-rectangle-list"
                @label="admin.users.check_sso.text"
                @title="admin.users.check_sso.title"
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
      @connectorTagName="div"
      @name="after-user-details"
      @outletArgs={{lazyHash model=@controller.model}}
    />
  </span>

  <section>
    <hr />
    <div class="admin-user__danger-controls">
      {{#if @controller.model.active}}
        {{#if @controller.model.can_impersonate}}
          <DButton
            class="btn-danger btn-impersonate"
            @action={{@controller.impersonate}}
            @icon="crosshairs"
            @isLoading={{@controller.isLoading}}
            @label="admin.impersonate.title"
            @title="admin.impersonate.help"
          />
        {{/if}}
      {{/if}}

      {{#if @controller.model.can_be_anonymized}}
        <DButton
          class="btn-danger btn-anonymize"
          @action={{@controller.anonymize}}
          @icon="triangle-exclamation"
          @label="admin.user.anonymize"
        />
      {{/if}}

      {{#if @controller.model.canBeDeleted}}
        <DropdownSelectBox
          class="btn-user-delete"
          @content={{@controller.deleteUserOptions}}
          @nameProperty="label"
          @onChange={{@controller.destroyUser}}
          @options={{hash
            icon="trash-can"
            showCaret=true
            translatedNone=(i18n "admin.user.delete")
            customStyle=true
            btnCustomClasses="btn-danger"
          }}
        />
      {{/if}}

      {{#if @controller.model.can_be_merged}}
        <DButton
          class="btn-danger btn-user-merge"
          @action={{@controller.promptTargetUser}}
          @icon="left-right"
          @label="admin.user.merge.button"
        />
      {{/if}}
    </div>

    {{#if @controller.deleteExplanation}}
      <div class="pull-right">
        {{dIcon "triangle-exclamation"}}
        <span class="delete-explanation">
          {{@controller.deleteExplanation}}
        </span>
      </div>
    {{/if}}
  </section>

  <div class="clearfix"></div>
</template>
