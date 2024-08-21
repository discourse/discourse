<DModal
  class="{{@model.penaltyType}}-user-modal"
  @title={{i18n this.modalTitle}}
  @closeModal={{this.warnBeforeClosing}}
  @flash={{this.flash}}
>
  <:body>
    {{#if this.canPenalize}}
      <div class="penalty-duration-controls">
        {{#if (eq @model.penaltyType "suspend")}}
          <FutureDateInput
            @label="admin.user.suspend_duration"
            @clearable={{false}}
            @input={{this.penalizeUntil}}
            @onChangeInput={{fn (mut this.penalizeUntil)}}
            class="suspend-until"
          />
        {{else if (eq @model.penaltyType "silence")}}
          <FutureDateInput
            @label="admin.user.silence_duration"
            @clearable={{false}}
            @input={{this.penalizeUntil}}
            @onChangeInput={{fn (mut this.penalizeUntil)}}
            class="silence-until"
          />
        {{/if}}
      </div>
      {{#if (eq @model.penaltyType "suspend")}}
        <div class="penalty-reason-visibility">
          {{#if this.siteSettings.hide_suspension_reasons}}
            {{html-safe (i18n "admin.user.suspend_reason_hidden_label")}}
          {{else}}
            {{html-safe (i18n "admin.user.suspend_reason_label")}}
          {{/if}}
        </div>
      {{/if}}
      <AdminPenaltyReason
        @penaltyType={{@model.penaltyType}}
        @reason={{this.reason}}
        @message={{this.message}}
      />
      {{#if @model.postId}}
        <AdminPenaltyPostAction
          @postId={{@model.postId}}
          @postAction={{this.postAction}}
          @postEdit={{this.postEdit}}
        />
      {{/if}}
      {{#if @model.user.similar_users_count}}
        <AdminPenaltySimilarUsers
          @penaltyType={{@model.penaltyType}}
          @user={{@model.user}}
          @selectedUserIds={{this.otherUserIds}}
          @onUsersChanged={{this.similarUsersChanged}}
        />
      {{/if}}
    {{else}}
      {{#if (eq @model.penaltyType "suspend")}}
        <div class="cant-suspend">{{i18n "admin.user.cant_suspend"}}</div>
      {{else if (eq @model.penaltyType "silence")}}
        <div class="cant-silence">{{i18n "admin.user.cant_silence"}}</div>
      {{/if}}
    {{/if}}
  </:body>
  <:footer>
    <div class="penalty-history">{{html-safe this.penaltyHistory}}</div>
    <DButton
      class="btn-danger perform-penalize"
      @action={{this.penalizeUser}}
      @disabled={{this.submitDisabled}}
      @icon="ban"
      @label={{this.buttonLabel}}
    />
    <DButton
      class="btn-flat d-modal-cancel"
      @action={{this.warnBeforeClosing}}
      @label="cancel"
    />
  </:footer>
</DModal>