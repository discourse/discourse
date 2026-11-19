import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";

interface DHtmlWithLinksSignature {
  Element: HTMLDivElement;

  Blocks: {
    /** Content with links. External links follow the user's new-tab preference. */
    default: [];
  };
}

export default class DHtmlWithLinks extends Component<DHtmlWithLinksSignature> {
  @action
  click(event: MouseEvent) {
    if ((event.target as HTMLElement).tagName === "A") {
      if (shouldOpenInNewTab((event.target as HTMLAnchorElement).href)) {
        openLinkInNewTab(event, event.target as HTMLAnchorElement);
      }
    }
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div ...attributes {{on "click" this.click}}>{{yield}}</div>
  </template>
}
