import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";

export default class PostVotingAnswerButton extends Component {
  static shouldRender(args) {
    return args.state.canCreatePost && args.post.post_number === 1;
  }

  @service site;

  get showLabel() {
    return this.site.desktopView;
  }

  <template>
    <DButton
      class={{concatClass
        "post-action-menu__post-voting-answer"
        "reply"
        (if this.showLabel "create fade-out")
      }}
      ...attributes
      @action={{@buttonActions.replyToPost}}
      @icon="reply"
      @label={{if this.showLabel "post_voting.topic.answer.label"}}
      @title="post_voting.topic.answer.help"
    />
  </template>
}
