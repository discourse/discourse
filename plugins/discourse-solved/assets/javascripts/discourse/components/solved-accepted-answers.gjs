import Component from "@glimmer/component";
import { SolvedAcceptedAnswer } from "./solved-accepted-answer";

export default class SolvedAcceptedAnswers extends Component {
  get topic() {
    return this.args.post.topic;
  }

  get acceptedAnswers() {
    return this.topic.accepted_answers ?? [];
  }

  <template>
    {{#each this.acceptedAnswers as |answer|}}
      <SolvedAcceptedAnswer
        @answer={{answer}}
        @topic={{this.topic}}
        @post={{@post}}
        @decoratorState={{@decoratorState}}
      />
    {{/each}}
  </template>
}
