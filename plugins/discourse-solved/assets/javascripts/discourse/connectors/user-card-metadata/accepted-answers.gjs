/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
export default class AcceptedAnswers extends Component {
  <template>
    <div class="user-card-metadata-outlet accepted-answers" ...attributes>
      {{#if this.user.accepted_answers}}
        <span class="desc">{{i18n "solutions"}}</span>
        <span>{{this.user.accepted_answers}}</span>
      {{/if}}
    </div>
  </template>
}
