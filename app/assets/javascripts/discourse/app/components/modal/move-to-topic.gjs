import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import ChooseMessage from "discourse/components/choose-message";
import ChooseTopic from "discourse/components/choose-topic";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import PluginOutlet from "discourse/components/plugin-outlet";
import RadioButton from "discourse/components/radio-button";
import TextField from "discourse/components/text-field";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { mergeTopic, movePosts } from "discourse/models/topic";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import TagChooser from "select-kit/components/tag-chooser";

export default class MoveToTopic extends Component {
  @service currentUser;
  @service site;

  @tracked topicName;
  @tracked saving = false;
  @tracked categoryId;
  @tracked tags;
  @tracked participants = [];
  @tracked chronologicalOrder = false;
  @tracked selection = "new_topic";
  @tracked selectedTopic;
  @tracked flash;

  constructor() {
    super(...arguments);
    if (this.args.model.topic.isPrivateMessage) {
      this.selection = this.canSplitToPM ? "new_message" : "existing_message";
    } else if (!this.canSplitTopic) {
      this.selection = "existing_topic";
    }
  }

  get newTopic() {
    return this.selection === "new_topic";
  }

  get existingTopic() {
    return this.selection === "existing_topic";
  }

  get newMessage() {
    return this.selection === "new_message";
  }

  get existingMessage() {
    return this.selection === "existing_message";
  }

  get buttonDisabled() {
    return (
      this.saving || (isEmpty(this.selectedTopic) && isEmpty(this.topicName))
    );
  }

  get buttonTitle() {
    if (this.newTopic) {
      return "topic.split_topic.title";
    } else if (this.existingTopic) {
      return "topic.merge_topic.title";
    } else if (this.newMessage) {
      return "topic.move_to_new_message.title";
    } else if (this.existingMessage) {
      return "topic.move_to_existing_message.title";
    } else {
      return "saving";
    }
  }

  get canSplitTopic() {
    return (
      !this.args.model.selectedAllPosts &&
      this.args.model.selectedPosts.length > 0 &&
      this.args.model.selectedPosts.sort(
        (a, b) => a.post_number - b.post_number
      )[0].post_type === this.site.get("post_types.regular")
    );
  }

  get canSplitToPM() {
    return this.canSplitTopic && this.currentUser?.admin;
  }

  get canAddTags() {
    return this.site.can_create_tag;
  }

  get canTagMessages() {
    return this.site.can_tag_pms;
  }

  @action
  performMove() {
    if (this.newTopic) {
      this.movePostsTo("newTopic");
    } else if (this.existingTopic) {
      this.movePostsTo("existingTopic");
    } else if (this.newMessage) {
      this.movePostsTo("newMessage");
    } else if (this.existingMessage) {
      this.movePostsTo("existingMessage");
    }
  }

  @action
  async movePostsTo(type) {
    this.saving = true;
    this.flash = null;
    let mergeOptions, moveOptions;

    if (type === "existingTopic") {
      mergeOptions = {
        destination_topic_id: this.selectedTopic.id,
        chronological_order: this.chronologicalOrder,
      };
      moveOptions = {
        post_ids: this.args.model.selectedPostIds,
        ...mergeOptions,
      };
    } else if (type === "existingMessage") {
      mergeOptions = {
        destination_topic_id: this.selectedTopic.id,
        participants: this.participants.join(","),
        archetype: "private_message",
        chronological_order: this.chronologicalOrder,
      };
      moveOptions = {
        post_ids: this.args.model.selectedPostIds,
        ...mergeOptions,
      };
    } else if (type === "newTopic") {
      mergeOptions = {};
      moveOptions = {
        title: this.topicName,
        post_ids: this.args.model.selectedPostIds,
        category_id: this.categoryId,
        tags: this.tags,
      };
    } else {
      mergeOptions = {};
      moveOptions = {
        title: this.topicName,
        post_ids: this.args.model.selectedPostIds,
        tags: this.tags,
        archetype: "private_message",
      };
    }

    mergeOptions = applyValueTransformer(
      "move-to-topic-merge-options",
      mergeOptions
    );
    moveOptions = applyValueTransformer(
      "move-to-topic-move-options",
      moveOptions
    );

    try {
      let result;
      if (this.args.model.selectedAllPosts) {
        result = await mergeTopic(this.args.model.topic.id, mergeOptions);
      } else {
        result = await movePosts(this.args.model.topic.id, moveOptions);
      }

      this.args.closeModal();
      this.args.model.toggleMultiSelect();
      DiscourseURL.routeTo(result.url);
    } catch {
      this.flash = i18n("topic.move_to.error");
    } finally {
      this.saving = false;
    }
  }

  @action
  updateTopicName(newName) {
    this.topicName = newName;
  }

  @action
  updateCategoryId(newId) {
    this.categoryId = newId;
  }

  @action
  updateTags(newTags) {
    this.tags = newTags;
  }

  @action
  newTopicSelected(topic) {
    this.selectedTopic = topic;
  }

  <template>
    <DModal
      id="choosing-topic"
      @title={{i18n "topic.move_to.title"}}
      @closeModal={{@closeModal}}
      class="choose-topic-modal"
      @flash={{this.flash}}
      @flashType="error"
    >
      <:body>
        {{#if @model.topic.isPrivateMessage}}
          <div class="radios">
            {{#if this.canSplitToPM}}
              <label class="radio-label" for="move-to-new-message">
                <RadioButton
                  id="move-to-new-message"
                  @name="move-to-entity"
                  @value="new_message"
                  @selection={{this.selection}}
                />
                <b>{{i18n "topic.move_to_new_message.radio_label"}}</b>
              </label>
            {{/if}}

            <label class="radio-label" for="move-to-existing-message">
              <RadioButton
                id="move-to-existing-message"
                @name="move-to-entity"
                @value="existing_message"
                @selection={{this.selection}}
              />
              <b>{{i18n "topic.move_to_existing_message.radio_label"}}</b>
            </label>
          </div>

          {{#if this.canSplitTopic}}
            {{#if this.newMessage}}
              <p>
                {{htmlSafe
                  (i18n
                    "topic.move_to_new_message.instructions"
                    count=@model.selectedPostsCount
                  )
                }}
              </p>
              <form>
                <label>{{i18n
                    "topic.move_to_new_message.message_title"
                  }}</label>
                <TextField
                  @value={{this.topicName}}
                  @placeholderKey="composer.title_placeholder"
                  id="split-topic-name"
                />

                {{#if this.canTagMessages}}
                  <label>{{i18n "tagging.tags"}}</label>
                  <TagChooser @tags={{this.tags}} />
                {{/if}}
              </form>
            {{/if}}
          {{/if}}

          {{#if this.existingMessage}}
            <p>
              {{htmlSafe
                (i18n
                  "topic.move_to_existing_message.instructions"
                  count=@model.selectedPostsCount
                )
              }}
            </p>
            <form>
              <ChooseMessage
                @currentTopicId={{@model.topic.id}}
                @setSelectedTopicId={{fn (mut this.selectedTopic)}}
                @selectedTopicId={{this.selectedTopic.id}}
              />

              <label>{{i18n "topic.move_to_new_message.participants"}}</label>
              <EmailGroupUserChooser
                class="participant-selector"
                @value={{this.participants}}
                @onChange={{fn (mut this.participants)}}
              />

              {{#if this.selectedTopic}}
                <hr />
                <label for="chronological-order" class="checkbox-label">
                  <Input
                    id="chronological-order"
                    @type="checkbox"
                    @checked={{this.chronologicalOrder}}
                  />
                  {{i18n "topic.merge_topic.chronological_order"}}
                </label>
              {{/if}}
            </form>
          {{/if}}

        {{else}}
          <div class="radios">
            {{#if this.canSplitTopic}}
              <label class="radio-label" for="move-to-new-topic">
                <RadioButton
                  id="move-to-new-topic"
                  @name="move-to-entity"
                  @value="new_topic"
                  @selection={{this.selection}}
                />
                <b>{{i18n "topic.split_topic.radio_label"}}</b>
              </label>
            {{/if}}

            <label class="radio-label" for="move-to-existing-topic">
              <RadioButton
                id="move-to-existing-topic"
                @name="move-to-entity"
                @value="existing_topic"
                @selection={{this.selection}}
              />
              <b>{{i18n "topic.merge_topic.radio_label"}}</b>
            </label>

            {{#if this.canSplitToPM}}
              <label class="radio-label" for="move-to-new-message">
                <RadioButton
                  id="move-to-new-message"
                  @name="move-to-entity"
                  @value="new_message"
                  @selection={{this.selection}}
                />
                <b>{{i18n "topic.move_to_new_message.radio_label"}}</b>
              </label>
            {{/if}}
          </div>

          <PluginOutlet @name="move-to-topic-after-radio-buttons" />

          {{#if this.existingTopic}}
            <p>
              {{htmlSafe
                (i18n
                  "topic.merge_topic.instructions"
                  count=@model.selectedPostsCount
                )
              }}
            </p>
            <form>
              <ChooseTopic
                @topicChangedCallback={{this.newTopicSelected}}
                @currentTopicId={{@model.topic.id}}
                @selectedTopicId={{this.selectedTopic.id}}
              />

              {{#if this.selectedTopic}}
                <hr />
                <label for="chronological-order" class="checkbox-label">
                  <Input
                    id="chronological-order"
                    @type="checkbox"
                    @checked={{this.chronologicalOrder}}
                  />
                  {{i18n "topic.merge_topic.chronological_order"}}
                </label>
              {{/if}}
            </form>
          {{/if}}

          {{#if this.canSplitTopic}}
            {{#if this.newTopic}}
              <p>
                {{htmlSafe
                  (i18n
                    "topic.split_topic.instructions"
                    count=@model.selectedPostsCount
                  )
                }}
              </p>
              <form class="split-new-topic-form">
                <div class="control-group">
                  <label>{{i18n "topic.split_topic.topic_name"}}</label>
                  <TextField
                    @value={{this.topicName}}
                    @placeholderKey="composer.title_placeholder"
                    id="split-topic-name"
                  />
                  <PluginOutlet
                    @name="split-new-topic-title-after"
                    @outletArgs={{lazyHash
                      selectedPosts=@model.selectedPosts
                      updateTopicName=this.updateTopicName
                    }}
                  />
                </div>

                <div class="control-group">
                  <label>{{i18n "categories.category"}}</label>
                  <CategoryChooser
                    @value={{this.categoryId}}
                    class="small"
                    @onChange={{fn (mut this.categoryId)}}
                  />
                  <PluginOutlet
                    @name="split-new-topic-category-after"
                    @outletArgs={{lazyHash
                      selectedPosts=@model.selectedPosts
                      updateCategoryId=this.updateCategoryId
                    }}
                  />
                </div>

                {{#if this.canAddTags}}
                  <div class="control-group">
                    <label>{{i18n "tagging.tags"}}</label>
                    <TagChooser
                      @tags={{this.tags}}
                      @categoryId={{this.categoryId}}
                    />
                    <PluginOutlet
                      @name="split-new-topic-tag-after"
                      @outletArgs={{lazyHash
                        selectedPosts=@model.selectedPosts
                        updateTags=this.updateTags
                        tags=this.tags
                      }}
                    />
                  </div>
                {{/if}}
              </form>
            {{/if}}
          {{/if}}

          {{#if this.canSplitTopic}}
            {{#if this.newMessage}}
              <p>
                {{htmlSafe
                  (i18n
                    "topic.move_to_new_message.instructions"
                    count=@model.selectedPostsCount
                  )
                }}
              </p>
              <form>
                <label>{{i18n
                    "topic.move_to_new_message.message_title"
                  }}</label>
                <TextField
                  @value={{this.topicName}}
                  @placeholderKey="composer.title_placeholder"
                  id="split-topic-name"
                />

                {{#if this.canTagMessages}}
                  <label>{{i18n "tagging.tags"}}</label>
                  <TagChooser @tags={{this.tags}} />
                {{/if}}
              </form>
            {{/if}}
          {{/if}}
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @disabled={{this.buttonDisabled}}
          @action={{this.performMove}}
          @icon="right-from-bracket"
          @label={{this.buttonTitle}}
        />
      </:footer>
    </DModal>
  </template>
}
