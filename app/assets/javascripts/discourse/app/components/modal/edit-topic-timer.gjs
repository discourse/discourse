<DModal
  @title={{i18n "topic.topic_status_update.title"}}
  @flash={{this.flash}}
  @closeModal={{@closeModal}}
  autoFocus="false"
  id="topic-timer-modal"
  class="edit-topic-timer-modal"
>
  <:body>
    {{#if this.topicTimer}}
      <EditTopicTimerForm
        @topic={{@model.topic}}
        @topicTimer={{this.topicTimer}}
        @timerTypes={{this.publicTimerTypes}}
        @onChangeStatusType={{this.onChangeStatusType}}
        @onChangeInput={{this.onChangeInput}}
      />
    {{/if}}
  </:body>
  <:footer>
    <DButton
      class="btn-primary"
      @disabled={{this.saveDisabled}}
      @label="topic.topic_status_update.save"
      @action={{this.saveTimer}}
      @isLoading={{this.loading}}
    />
    {{#if this.topicTimer.execute_at}}
      <DButton
        class="btn-danger"
        @action={{this.removeTimer}}
        @label="topic.topic_status_update.remove"
      />
    {{/if}}
  </:footer>
</DModal>