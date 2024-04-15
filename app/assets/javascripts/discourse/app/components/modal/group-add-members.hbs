<DModal
  @title={{this.title}}
  @closeModal={{@closeModal}}
  class="group-add-members-modal"
  @flash={{this.flash}}
>
  <:body>
    <form class="form-vertical group-add-members">
      <p>{{i18n "groups.add_members.description"}}</p>
      <div class="input-group">
        <EmailGroupUserChooser
          @value={{this.usernamesAndEmails}}
          @onChange={{this.setUsernamesAndEmails}}
          @options={{hash
            allowEmails=this.currentUser.can_invite_to_forum
            filterPlaceholder=(if
              this.currentUser.can_invite_to_forum
              "groups.add_members.usernames_or_emails_placeholder"
              "groups.add_members.usernames_placeholder"
            )
          }}
        />
      </div>

      {{#if @model.can_admin_group}}
        <div class="input-group">
          <label>
            <Input
              id="set-owner"
              @type="checkbox"
              @checked={{this.setOwner}}
              disabled={{this.emails}}
            />
            {{i18n "groups.add_members.set_owner"}}
          </label>
        </div>
      {{/if}}

      <div class="input-group">
        <label>
          <Input
            @type="checkbox"
            @checked={{this.notifyUsers}}
            disabled={{and (not this.usernames) this.emails}}
          />
          {{i18n "groups.add_members.notify_users"}}
        </label>
      </div>
    </form>
  </:body>
  <:footer>
    <DButton
      @action={{this.addMembers}}
      class="add btn-primary"
      @icon="plus"
      @disabled={{or this.loading (not this.usernamesAndEmails)}}
      @label="groups.add"
    />
  </:footer>
</DModal>