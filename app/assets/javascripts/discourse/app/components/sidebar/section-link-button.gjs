import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";

export default class SidebarSectionLinkButton extends Component {
  @action
  handleClick() {
    this.args.action(event);
    if (this.args.close) {
      this.args.close();
    }
  }

  <template>
    <div class="sidebar-section-link-wrapper">
      <button
        {{on "click" this.handleClick}}
        type="button"
        class="sidebar-section-link sidebar-row --link-button"
        data-list-item-name={{@text}}
      >
        <span class="sidebar-section-link-prefix icon">
          {{icon @icon}}
        </span>

        <span class="sidebar-section-link-content-text">
          {{@text}}
        </span>
      </button>
    </div>
  </template>
}
