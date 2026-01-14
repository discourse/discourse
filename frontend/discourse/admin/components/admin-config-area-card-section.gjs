import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";

export default class AdminConfigAreaCardSection extends Component {
  @tracked collapsed = this.args.collapsed;

  get headerCaretIcon() {
    return this.collapsed ? "angle-right" : "angle-down";
  }

  @action
  toggleSectionDisplay() {
    if (!this.args.collapsable) {
      return;
    }
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class="admin-config-area-card-section" ...attributes>
      <div
        class={{concatClass
          "admin-config-area-card-section__header-wrapper"
          (if @collapsable "collapsable")
        }}
        role="button"
        {{on "click" this.toggleSectionDisplay}}
      >
        <h4 class="admin-config-area-card-section__title">{{@heading}}</h4>
        {{#if @collapsable}}
          {{icon this.headerCaretIcon}}
        {{/if}}
      </div>
      {{#unless this.collapsed}}
        <div class="admin-config-area-card-section__content">
          {{yield to="content"}}
        </div>
      {{/unless}}
    </section>
  </template>
}
