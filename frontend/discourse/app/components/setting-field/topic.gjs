import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import Topic from "discourse/models/topic";
import TopicChooser from "discourse/select-kit/components/topic-chooser";

export default class SettingFieldTopic extends Component {
  @tracked topic = null;

  constructor() {
    super(...arguments);

    if (this.args.field.value) {
      this.loadTopic();
    }
  }

  get content() {
    return this.topic ? [this.topic] : [];
  }

  @action
  onChange(topicId, topic) {
    this.topic = topic;
    this.args.field.set(topicId);
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
      <TopicChooser
        @content={{this.content}}
        @onChange={{this.onChange}}
        @options={{hash castInteger=true disabled=@field.disabled}}
        @value={{@field.value}}
      />
    </@field.Control>
  </template>
}
