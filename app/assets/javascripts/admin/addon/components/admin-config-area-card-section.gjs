import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreaCardSection extends Component {
  @tracked collapsed = this.args.collapsed;

  get computedHeading() {
    if (this.args.heading) {
      return i18n(this.args.heading);
    }
    return this.args.translatedHeading;
  }

  get headerCaretIcon() {
    return this.collapsed ? "plus" : "minus";
  }

  @action
  toggleSectionDisplay() {
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class="admin-config-area-card-section" ...attributes>
      <div class="admin-config-area-card-section__header-wrapper">
        <h4
          class="admin-config-area-card-section__title"
        >{{this.computedHeading}}</h4>
        {{#if @collapsable}}
          <DButton
            @title="sidebar.toggle_section"
            @action={{this.toggleSectionDisplay}}
            class="admin-config-area-card-section__toggle-button btn-transparent"
          >
            {{icon this.headerCaretIcon}}
          </DButton>
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
