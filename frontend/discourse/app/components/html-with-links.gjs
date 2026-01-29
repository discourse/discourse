import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";

export default class HtmlWithLinks extends Component {
  @action
  click(event) {
    if (event.target.tagName === "A") {
      if (shouldOpenInNewTab(event.target.href)) {
        openLinkInNewTab(event, event.target);
      }
    }
  }

  <template>
    <div {{on "click" this.click}} ...attributes>{{yield}}</div>
  </template>
}
