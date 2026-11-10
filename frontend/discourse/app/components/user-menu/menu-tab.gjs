import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class UserMenuTab extends Component {
  get isActive() {
    return this.args.tab.id === this.args.currentTabId;
  }

  get classNames() {
    const list = ["btn", "btn-flat", "btn-icon", "no-text", "user-menu-tab"];
    if (this.isActive) {
      list.push("active");
    }
    return list.join(" ");
  }

  get id() {
    return `user-menu-button-${this.args.tab.id}`;
  }

  get tabIndex() {
    return this.isActive ? "0" : "-1";
  }

  get ariaControls() {
    return `quick-access-${this.args.tab.id}`;
  }

  <template>
    <a
      aria-controls={{this.ariaControls}}
      aria-label={{@tab.title}}
      aria-selected={{if this.isActive "true" "false"}}
      class={{this.classNames}}
      data-tab-number={{@tab.position}}
      href={{@tab.linkWhenActive}}
      id={{this.id}}
      role="tab"
      tabindex={{this.tabIndex}}
      title={{@tab.title}}
      {{on "click" @onTabClick}}
      {{on "keydown" @onTabClick}}
    >
      {{dIcon @tab.icon}}
      {{#if @tab.count}}
        <span
          aria-hidden="true"
          class="badge-notification"
        >{{@tab.count}}</span>
      {{/if}}
      {{yield}}
    </a>
  </template>
}
