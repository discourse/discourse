import Component from "@ember/component";
import { fn } from "@ember/helper";
import { alias, equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { and } from "truth-helpers";
import ChooseTopic from "discourse/components/choose-topic";
import RadioButton from "discourse/components/radio-button";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import TagChooser from "select-kit/components/tag-chooser";

export const NEW_TOPIC_SELECTION = "new_topic";
export const EXISTING_TOPIC_SELECTION = "existing_topic";
export const NEW_MESSAGE_SELECTION = "new_message";

export default class ChatToTopicSelector extends Component {
  newTopicSelection = NEW_TOPIC_SELECTION;
  existingTopicSelection = EXISTING_TOPIC_SELECTION;
  newMessageSelection = NEW_MESSAGE_SELECTION;
  selection = null;

  @equal("selection", NEW_TOPIC_SELECTION) newTopic;
  @equal("selection", EXISTING_TOPIC_SELECTION) existingTopic;
  @equal("selection", NEW_MESSAGE_SELECTION) newMessage;
  @alias("site.can_create_tag") canAddTags;
  @alias("site.can_tag_pms") canTagMessages;

  topicTitle = null;
  categoryId = null;
  tags = null;
  selectedTopicId = null;
  chatMessageIds = null;
  chatChannelId = null;

  @discourseComputed()
  newTopicInstruction() {
    return htmlSafe(this.instructionLabels[NEW_TOPIC_SELECTION]);
  }

  @discourseComputed()
  existingTopicInstruction() {
    return htmlSafe(this.instructionLabels[EXISTING_TOPIC_SELECTION]);
  }

  @discourseComputed()
  newMessageInstruction() {
    return htmlSafe(this.instructionLabels[NEW_MESSAGE_SELECTION]);
  }

  <template>
    <div class="chat-to-topic-selector">
      <div class="radios">
        <label class="radio-label" for="move-to-new-topic">
          <RadioButton
            @id="move-to-new-topic"
            @name="move-to-entity"
            @value={{this.newTopicSelection}}
            @selection={{this.selection}}
          />
          <b>{{i18n "topic.split_topic.radio_label"}}</b>
        </label>

        <label class="radio-label" for="move-to-existing-topic">
          <RadioButton
            @id="move-to-existing-topic"
            @name="move-to-entity"
            @value={{this.existingTopicSelection}}
            @selection={{this.selection}}
          />
          <b>{{i18n "topic.merge_topic.radio_label"}}</b>
        </label>

        {{#if this.allowNewMessage}}
          <label class="radio-label" for="move-to-new-message">
            <RadioButton
              @id="move-to-new-message"
              @name="move-to-entity"
              @value={{this.newMessageSelection}}
              @selection={{this.selection}}
            />
            <b>{{i18n "topic.move_to_new_message.radio_label"}}</b>
          </label>
        {{/if}}
      </div>

      {{#if this.newTopic}}
        <p>{{this.newTopicInstruction}}</p>

        <form>
          <label for="split-topic-name">
            {{i18n "topic.split_topic.topic_name"}}
          </label>

          <TextField
            @value={{this.topicTitle}}
            @placeholderKey="composer.title_placeholder"
            @id="split-topic-name"
          />

          <label>{{i18n "categories.category"}}</label>

          <CategoryChooser
            @id="new-topic-category-selector"
            @value={{this.categoryId}}
            @onChange={{fn (mut this.categoryId)}}
            class="small"
          />

          {{#if this.canAddTags}}
            <label>{{i18n "tagging.tags"}}</label>
            <TagChooser
              @tags={{this.tags}}
              @filterable={{true}}
              @categoryId={{this.categoryId}}
            />
          {{/if}}
        </form>
      {{/if}}

      {{#if this.existingTopic}}
        <p>{{this.existingTopicInstruction}}</p>
        <form>
          <ChooseTopic
            @topicChangedCallback={{@topicChangedCallback}}
            @selectedTopicId={{@selectedTopicId}}
          />
        </form>
      {{/if}}

      {{#if (and this.allowNewMessage this.newMessage)}}
        <p>{{this.newMessageInstruction}}</p>

        <form>
          <label for="split-message-title">
            {{i18n "topic.move_to_new_message.message_title"}}
          </label>

          <TextField
            @value={{this.topicTitle}}
            @placeholderKey="composer.title_placeholder"
            @id="split-message-title"
          />

          {{#if this.canTagMessages}}
            <label>{{i18n "tagging.tags"}}</label>
            <TagChooser @tags={{this.tags}} @filterable={{true}} />
          {{/if}}
        </form>
      {{/if}}
    </div>
  </template>
}
