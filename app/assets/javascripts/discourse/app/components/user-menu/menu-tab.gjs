import Component from "@glimmer/component";

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
}

<a
  role="tab"
  class={{this.classNames}}
  id={{this.id}}
  tabindex={{this.tabIndex}}
  title={{@tab.title}}
  aria-label={{@tab.title}}
  aria-selected={{if this.isActive "true" "false"}}
  aria-controls={{this.ariaControls}}
  data-tab-number={{@tab.position}}
  href={{@tab.linkWhenActive}}
  {{on "click" @onTabClick}}
  {{on "keydown" @onTabClick}}
>
  {{d-icon @tab.icon}}
  {{#if @tab.count}}
    <span aria-hidden="true" class="badge-notification">{{@tab.count}}</span>
  {{/if}}
  {{yield}}
</a>