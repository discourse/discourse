import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";

export default class TopicCreatorColumn extends Component {
  get topicCreator() {
    return {
      user: this.args.topic.creator,
      class: "--topic-creator",
    };
  }

  <template>
    <div class={{this.topicCreator.class}}>
      {{avatar this.topicCreator.user}}
    </div>
  </template>
}
