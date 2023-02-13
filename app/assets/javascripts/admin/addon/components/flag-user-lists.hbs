<div class="flagged-by">
  <div class="user-list-title">
    {{i18n "admin.flags.flagged_by"}}
  </div>
  <div class="flag-users">
    {{#each this.flaggedPost.post_actions as |postAction|}}
      <FlagUser @user={{postAction.user}} @date={{postAction.created_at}}>
        <div class="flagger-flag-type">
          {{post-action-title
            postAction.post_action_type_id
            postAction.name_key
          }}
        </div>
        <UserFlagPercentage
          @agreed={{postAction.user.flags_agreed}}
          @disagreed={{postAction.user.flags_disagreed}}
          @ignored={{postAction.user.flags_ignored}}
        />
      </FlagUser>
    {{/each}}
  </div>
</div>

{{#if this.showResolvedBy}}
  <div class="flagged-post-resolved-by">
    <div class="user-list-title">
      {{i18n "admin.flags.resolved_by"}}
    </div>
    <div class="flag-users">
      {{#each this.flaggedPost.post_actions as |postAction|}}
        <FlagUser
          @user={{postAction.disposed_by}}
          @date={{postAction.disposed_at}}
        >
          {{disposition-icon postAction.disposition}}
          {{#if postAction.staff_took_action}}
            {{d-icon "gavel" title="admin.flags.took_action"}}
          {{/if}}
        </FlagUser>
      {{/each}}
    </div>
  </div>
{{/if}}