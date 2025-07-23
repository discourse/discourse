import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("div")
@classNames("user-card-metadata-outlet", "accepted-answers")
export default class AcceptedAnswers extends Component {
  <template>
    {{#if this.user.accepted_answers}}
      <span class="desc">{{i18n "solutions"}}</span>
      <span>{{this.user.accepted_answers}}</span>
    {{/if}}
  </template>
}
