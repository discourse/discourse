import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreaCard extends Component {
  @tracked collapsed = this.args.collapsed;

  get computedHeading() {
    if (this.args.heading) {
      return i18n(this.args.heading);
    }
    return this.args.translatedHeading;
  }

  get hasHeading() {
    return this.args.heading || this.args.translatedHeading;
  }

  get computedDescription() {
    if (this.args.description) {
      return i18n(this.args.description);
    }
    return this.args.translatedDescription;
  }

  get hasDescription() {
    return this.args.description || this.args.translatedDescription;
  }

  get headerCaretIcon() {
    return this.collapsed ? "angle-right" : "angle-down";
  }

  @action
  toggleCardDisplay() {
    this.collapsed = !this.collapsed;
  }

  <template>
    <section class="admin-config-area-card" ...attributes>
      <div class="admin-config-area-card__header-wrapper">
        {{#if this.hasHeading}}
          <h3
            class="admin-config-area-card__title"
          >{{this.computedHeading}}</h3>
        {{else}}
          {{#if (has-block "header")}}
            <h3 class="admin-config-area-card__title">{{yield to="header"}}</h3>
          {{/if}}
        {{/if}}
        {{#if (has-block "headerAction")}}
          <div class="admin-config-area-card__header-action">
            {{yield to="headerAction"}}
          </div>
        {{/if}}

        {{#if @collapsable}}
          <DButton
            @title="sidebar.toggle_section"
            @action={{this.toggleCardDisplay}}
            class="admin-config-area-card__toggle-button btn-transparent"
          >
            {{icon this.headerCaretIcon}}
          </DButton>
        {{/if}}
      </div>
      {{#unless this.collapsed}}
        <div class="admin-config-area-card__content">
          {{#if this.hasDescription}}
            <p class="admin-config-area-card__description">
              {{this.computedDescription}}
            </p>
          {{/if}}
          {{yield to="content"}}
        </div>
      {{/unless}}
    </section>
  </template>
}
