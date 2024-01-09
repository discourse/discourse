import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import icon from "discourse-common/helpers/d-icon";
import SubTitle from "./sub-title";

export default class ChatNavbarTitle extends Component {
  get subTitleComponent() {
    return SubTitle;
  }

  <template>
    <div title={{@title}} class="c-navbar__title">
      {{#if (has-block)}}
        {{#if @icon}}
          {{icon @icon}}
        {{/if}}
        {{@title}}
        {{yield (hash SubTitle=this.subTitleComponent)}}
      {{else}}
        {{#if @icon}}
          {{icon @icon}}
        {{/if}}
        {{@title}}
      {{/if}}
    </div>
  </template>
}
