/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import TopicModel from "discourse/models/topic";
import TopicChooser from "discourse/select-kit/components/topic-chooser";
import DSelectTopic from "discourse/ui-kit/select/recipes/topics/d-select-topic";

export default class Topic extends Component {
  @service siteSettings;

  @tracked selectedTopic;
  @tracked selectedTopicId = this.args.value;
  @tracked topicLoading = false;

  constructor() {
    super(...arguments);

    // TODO (select-kit-replacement-cleanup): The new picker looks its held topic up itself.
    if (
      isPresent(this.selectedTopicId) &&
      !this.siteSettings.enable_new_select_controls
    ) {
      this.loadSelectedTopic();
    }
  }

  /** The held id; an unset setting holds an empty string. */
  get heldTopicId() {
    return isPresent(this.args.value) ? Number(this.args.value) : null;
  }

  get selectedTopicContent() {
    if (this.topicLoading || !this.selectedTopicId) {
      return [];
    }
    return [this.selectedTopic];
  }

  @action
  onChangeTopicSetting(topicId, topic) {
    this.args.changeValueCallback(topicId);
    this.selectedTopicId = topicId;
    this.selectedTopic = topic;
  }

  async loadSelectedTopic() {
    this.topicLoading = true;

    try {
      const topic = await TopicModel.find(this.selectedTopicId, {});
      this.onChangeTopicSetting(this.selectedTopicId, topic);
      this.topicLoading = false;
    } catch {
      // eslint-disable-next-line no-console
      console.error("Selected topic has been deleted.");
    } finally {
      this.topicLoading = false;
    }
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectTopic
        @clearable={{true}}
        @onChange={{@changeValueCallback}}
        @texts={{hash ariaLabel=@label}}
        @value={{this.heldTopicId}}
      />
    {{else}}
      <TopicChooser
        @content={{this.selectedTopicContent}}
        @onChange={{this.onChangeTopicSetting}}
        @options={{hash castInteger=true}}
        @value={{@value}}
      />
    {{/if}}
  </template>
}
