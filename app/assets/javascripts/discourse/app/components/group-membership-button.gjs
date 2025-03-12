{{#if this.canJoinGroup}}
  <DButton
    @action={{action "joinGroup"}}
    @icon="user-plus"
    @label="groups.join"
    @disabled={{this.updatingMembership}}
    class="btn-default group-index-join"
  />
{{else if this.canLeaveGroup}}
  <DButton
    @action={{action "leaveGroup"}}
    @icon="user-xmark"
    @label="groups.leave"
    @disabled={{this.updatingMembership}}
    class="btn-danger group-index-leave"
  />
{{else if this.canRequestMembership}}
  <DButton
    @action={{action "showRequestMembershipForm"}}
    @disabled={{this.loading}}
    @icon="user-plus"
    @label="groups.request"
    class="btn-default group-index-request"
  />
{{else}}
  {{yield}}
{{/if}}