/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isPresent } from "@ember/utils";
import TopicModel from "discourse/models/topic";
import TopicChooser from "discourse/select-kit/components/topic-chooser";

export default class Topic extends Component {
  @tracked selectedTopic;
  @tracked selectedTopicId = this.args.value;
  @tracked topicLoading = false;

  constructor() {
    super(...arguments);

    if (isPresent(this.selectedTopicId)) {
      this.loadSelectedTopic();
    }
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
    <TopicChooser
      @content={{this.selectedTopicContent}}
      @onChange={{this.onChangeTopicSetting}}
      @options={{hash castInteger=true}}
      @value={{@value}}
    />
  </template>
}
