import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";

export default class AdminConfigAreaCardSection extends Component {
  @tracked collapsed = this.args.collapsed;

  get headerCaretIcon() {
    return this.collapsed ? "angle-right" : "angle-down";
  }

  @action
  toggleSectionDisplay() {
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class="admin-config-area-card-section" ...attributes>
      <div class="admin-config-area-card-section__header-wrapper">
        <h4 class="admin-config-area-card-section__title">{{@heading}}</h4>
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
