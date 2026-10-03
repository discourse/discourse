import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import ClickTrack from "discourse/lib/click-track";

export default class LinksRedirect extends Component {
  @action
  click(event) {
    if (event.target.closest("a")) {
      return ClickTrack.trackClick(event, getOwner(this));
    }
  }

  <template>
    {{! eslint-disable ember/template-no-invalid-interactive }}
    <div ...attributes {{on "click" this.click}}>{{yield}}</div>
  </template>
}
