import Component from "@glimmer/component";

export default class ChatNavbarSubTitle extends Component {
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
