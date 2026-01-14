import Component from "@glimmer/component";

export default class MessagesSecondaryNav extends Component {
  get messagesNav() {
    return document.getElementById("user-navigation-secondary__horizontal-nav");
  }

  <template>
    {{#in-element this.messagesNav}}
      {{yield}}
    {{/in-element}}
  </template>
}
