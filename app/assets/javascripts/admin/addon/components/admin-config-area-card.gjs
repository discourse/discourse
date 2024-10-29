import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import I18n from "discourse-i18n";

export default class AdminConfigAreaCard extends Component {
  @tracked collapsed = false;

  get computedHeading() {
    if (this.args.heading) {
      return I18n.t(this.args.heading);
    }
    return this.args.translatedHeading;
  }

  get hasHeading() {
    return this.args.heading || this.args.translatedHeading;
  }

  get computedDescription() {
    if (this.args.description) {
      return I18n.t(this.args.description);
    }
    return this.args.translatedDescription;
  }

  get hasDescription() {
    return this.args.description || this.args.translatedDescription;
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
      </div>
      <div class="admin-config-area-card__content">
        {{#if this.hasDescription}}
          <p class="admin-config-area-card__description">
            {{this.computedDescription}}
          </p>
        {{/if}}
        {{yield to="content"}}
      </div>
    </section>
  </template>
}
