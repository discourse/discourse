<DModal
  @closeModal={{@closeModal}}
  class="feature-topic-on-profile choose-topic-modal"
  id="choosing-topic"
  @title={{i18n "user.feature_topic_on_profile.title"}}
>
  <:body>
    <ChooseTopic
      @topicChangedCallback={{this.newTopicSelected}}
      @currentTopicId={{@model.user.featured_topic.id}}
      @loadOnInit={{true}}
      @additionalFilters="status:public"
      @label="user.feature_topic_on_profile.search_label"
    />
  </:body>
  <:footer>
    <DButton
      @action={{this.save}}
      class="btn-primary save-featured-topic-on-profile"
      @disabled={{this.noTopicSelected}}
      @label="user.feature_topic_on_profile.save"
    />
    <DButton @action={{@closeModal}} @label="cancel" class="btn-flat" />
  </:footer>
</DModal>