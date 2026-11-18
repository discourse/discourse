import Component from "@glimmer/component";
import domFromString from "discourse/lib/dom-from-string";
import type Badge from "discourse/models/badge";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";

interface DBadgeButtonSignature {
  Args: {
    /** The badge to show. */
    badge: Badge;

    /** Whether to show the badge name next to its icon. Defaults to `true`. */
    showName?: boolean;
  };

  Element: HTMLSpanElement;

  Blocks: {
    /** Content added after the name. */
    default: [];
  };
}

export default class DBadgeButton extends Component<DBadgeButtonSignature> {
  get title() {
    const description = this.args.badge?.description;
    if (description) {
      return (domFromString(`<div>${description}</div>`)[0] as HTMLElement)
        .innerText;
    }
  }

  get showName() {
    return this.args.showName ?? true;
  }

  <template>
    <span
      class="user-badge
        {{@badge.badgeTypeClassName}}
        {{unless @badge.enabled 'disabled'}}"
      data-badge-name={{@badge.name}}
      title={{this.title}}
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
