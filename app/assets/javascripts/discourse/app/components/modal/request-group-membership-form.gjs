<DModal
  @title={{this.title}}
  @closeModal={{@closeModal}}
  @inline={{@inline}}
  class="request-group-membership-form"
>
  <:body>
    <div class="control-group">
      <label>
        {{i18n "groups.membership_request.reason"}}
      </label>

      <ExpandingTextArea
        {{on "input" (with-event-value (fn (mut this.reason)))}}
        value={{this.reason}}
        maxlength="5000"
      />
    </div>
  </:body>

  <:footer>
    <DButton
      @action={{this.requestMember}}
      @label="groups.membership_request.submit"
      @disabled={{this.disableSubmit}}
      class="btn-primary"
    />

    <DModalCancel @close={{@closeModal}} />
    <ConditionalLoadingSpinner @size="small" @condition={{this.loading}} />
  </:footer>
</DModal>