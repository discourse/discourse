import Component from "@glimmer/component";
import SubTitle from "./sub-title";

export default class ChatNavbarSubTitle extends Component {
  get subTitleComponent() {
    return SubTitle;
  }

  <template>
    <div class="c-navbar__sub-title">
      {{#if (has-block)}}
        {{yield}}
      {{else}}
        {{@title}}
      {{/if}}
    </div>
  </template>
}
