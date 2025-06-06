import Component from "@glimmer/component";
import avatar from "discourse/helpers/avatar";

export default class TopicCreatorColumn extends Component {
  get topicCreator() {
    return {
      user: this.args.topic.creator,
      username: this.args.topic.creator.username,
      class: "--topic-creator",
    };
  }

  <template>
    <div class={{this.topicUser.class}}>
      {{avatar this.topicCreator.user}}
      <span class="topic-creator__username">{{this.topicUser.username}}</span>
    </div>
  </template>
}
