{{#if this.inviteModel.error}}
  <div class="alert alert-error">
    {{html-safe this.errorMessage}}
  </div>
{{/if}}

<div class="body">
  {{#if this.inviteModel.finished}}
    {{#if this.inviteModel.inviteLink}}
      <GeneratedInviteLink
        @link={{this.inviteModel.inviteLink}}
        @email={{this.invitee}}
      />
    {{else}}
      <div class="success-message">
        {{html-safe this.successMessage}}
      </div>
    {{/if}}
  {{else}}
    <div class="invite-user-control">
      <label class="instructions">{{this.inviteInstructions}}</label>
      <div class="invite-user-input-wrapper">
        {{#if this.allowExistingMembers}}
          <EmailGroupUserChooser
            @value={{this.invitee}}
            @onChange={{action "updateInvitee"}}
            @options={{hash
              maximum=1
              allowEmails=this.canInviteViaEmail
              excludeCurrentUser=true
              includeMessageableGroups=this.isPM
              filterPlaceholder=this.placeholderKey
              fullWidthWrap=true
            }}
            class="invite-user-input"
          />
        {{else}}
          <TextField
            @value={{this.invitee}}
            @placeholderKey="topic.invite_reply.email_placeholder"
            class="email-or-username-input"
          />
        {{/if}}
        {{#if this.capabilities.hasContactPicker}}
          <DButton
            @icon="address-book"
            @action={{this.searchContact}}
            class="btn-primary open-contact-picker"
          />
        {{/if}}
      </div>
    </div>

    {{#if this.showGroups}}
      <div class="group-access-control">
        <label class="instructions {{this.showGroupsClass}}">
          {{i18n "topic.automatically_add_to_groups"}}
        </label>
        <GroupChooser
          @content={{this.allGroups}}
          @value={{this.groupIds}}
          @labelProperty="name"
          @onChange={{fn (mut this.groupIds)}}
        />
      </div>
    {{/if}}

    {{#if this.showCustomMessage}}
      <div class="show-custom-message-control">
        <label class="instructions">
          <DiscourseLinkedText
            @action={{action "showCustomMessageBox"}}
            @text="invite.custom_message"
            class="optional"
          />
        </label>
        {{#if this.hasCustomMessage}}
          <Textarea
            @value={{this.customMessage}}
            placeholder={{this.customMessagePlaceholder}}
          />
        {{/if}}
      </div>
    {{/if}}
  {{/if}}

  {{#if this.showApprovalMessage}}
    <label class="instructions approval-notice">
      {{i18n "invite.approval_not_required"}}
    </label>
  {{/if}}
</div>

<div class="footer">
  {{#if this.inviteModel.finished}}
    <DButton @action={{@closeModal}} @label="close" class="btn-primary" />
  {{else}}
    <DButton
      @icon={{this.inviteIcon}}
      @action={{this.createInvite}}
      @disabled={{this.disabled}}
      @label={{this.buttonTitle}}
      class="btn-primary send-invite"
    />
    {{#if this.showCopyInviteButton}}
      <DButton
        @icon="link"
        @action={{this.generateInviteLink}}
        @disabled={{this.disabledCopyLink}}
        @label="user.invited.generate_link"
        class="btn-primary generate-invite-link"
      />
    {{/if}}
  {{/if}}
</div>