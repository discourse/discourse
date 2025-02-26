<DModal
  @bodyClass="change-ownership"
  @closeModal={{@closeModal}}
  @title={{i18n "topic.change_owner.title"}}
  @flash={{this.flash}}
  @flashType="error"
  class="change-ownership-modal"
>
  <:body>
    <span>
      {{html-safe
        (i18n
          (if
            this.selectedPostsUsername
            "topic.change_owner.instructions"
            "topic.change_owner.instructions_without_old_user"
          )
          count=this.selectedPostsCount
          old_user=this.selectedPostsUsername
        )
      }}
    </span>

    <EmailGroupUserChooser
      @value={{this.newOwner}}
      @autofocus={{true}}
      @onChange={{this.updateNewOwner}}
      @options={{hash
        maximum=1
        filterPlaceholder="topic.change_owner.placeholder"
      }}
    />
  </:body>
  <:footer>
    <DButton
      {{on "click" this.changeOwnershipOfPosts}}
      @disabled={{this.buttonDisabled}}
      @label={{if this.saving "saving" "topic.change_owner.action"}}
      class="btn-primary"
    />
  </:footer>
</DModal>