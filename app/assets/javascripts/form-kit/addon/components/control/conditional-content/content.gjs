import Component from "@glimmer/component";
import { eq } from "truth-helpers";

export default class FKControlConditionalContentItem extends Component {
  <template>
    {{#if (eq @name @activeName)}}
      <div class="d-form__conditional-display__content">
        {{yield}}
      </div>
    {{/if}}
  </template>
}
