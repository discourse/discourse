import Component from "@glimmer/component";
import { eq } from "truth-helpers";

export default class FkControlConditionalDisplayContent extends Component {
  <template>
    {{#if (eq @name @activeName)}}
      {{yield}}
    {{/if}}
  </template>
}
