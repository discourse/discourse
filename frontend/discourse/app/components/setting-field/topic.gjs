import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import Topic from "discourse/models/topic";
import TopicChooser from "discourse/select-kit/components/topic-chooser";
import DSelectTopic from "discourse/ui-kit/select/recipes/topics/d-select-topic";

export default class SettingFieldTopic extends Component {
  @service siteSettings;

  @tracked topic = null;

  constructor() {
    super(...arguments);

    // TODO (select-kit-replacement-cleanup): The new picker looks its held topic up itself.
    if (
      this.args.field.value &&
      !this.siteSettings.enable_new_select_controls
    ) {
      this.loadTopic();
    }
  }

  get content() {
    return this.topic ? [this.topic] : [];
  }

  /** The held id; an unset setting holds an empty string. */
  get heldTopicId() {
    const value = this.args.field.value;
    return isPresent(value) ? Number(value) : null;
  }

  @action
  onChange(topicId, topic) {
    this.topic = topic;
    this.args.field.set(topicId);
  }

  /** Stores the picked topic's id, or an empty string once cleared. */
  @action
  onPickTopic(topicId) {
    this.args.field.set(topicId ?? "");
  }

  async loadTopic() {
    try {
      this.topic = await Topic.find(this.args.field.value, {});
    } catch {
      return;
    }
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectTopic
          @clearMode="button"
          @disabled={{@field.disabled}}
          @onChange={{this.onPickTopic}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{this.heldTopicId}}
        />
      {{else}}
        <TopicChooser
          @content={{this.content}}
          @onChange={{this.onChange}}
          @options={{hash castInteger=true disabled=@field.disabled}}
          @value={{@field.value}}
        />
      {{/if}}
    </@field.Control>
  </template>
}
