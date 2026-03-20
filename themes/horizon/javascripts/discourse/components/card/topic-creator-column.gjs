import Component from "@glimmer/component";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

export default class TopicCreatorColumn extends Component {
  get topicCreator() {
    return {
      user: this.args.topic.creator,
      class: "--topic-creator",
    };
  }

  <template>
    <div class={{this.topicCreator.class}}>
      {{dAvatar this.topicCreator.user}}
    </div>
  </template>
}
