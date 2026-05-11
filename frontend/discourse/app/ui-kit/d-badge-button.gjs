import Component from "@glimmer/component";
import domFromString from "discourse/lib/dom-from-string";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";

export default class DBadgeButton extends Component {
  get title() {
    const description = this.args.badge?.description;
    if (description) {
      return domFromString(`<div>${description}</div>`)[0].innerText;
    }
  }

  get showName() {
    return this.args.showName ?? true;
  }

  <template>
    <span
      title={{this.title}}
      data-badge-name={{@badge.name}}
      class="user-badge
        {{@badge.badgeTypeClassName}}
        {{unless @badge.enabled 'disabled'}}"
      ...attributes
    >
      {{dIconOrImage @badge}}
      {{#if this.showName}}
        <span class="badge-display-name">{{@badge.name}}</span>
      {{/if}}
      {{yield}}
    </span>
  </template>
}
