import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import {
  DangerButton,
  DefaultButton,
  PrimaryButton,
} from "discourse/components/d-page-action-button";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AdminSectionLandingItem extends Component {
  get title() {
    if (this.args.titleLabelTranslated) {
      return this.args.titleLabelTranslated;
    } else if (this.args.titleLabel) {
      return i18n(this.args.titleLabel);
    }
  }

  get description() {
    if (this.args.descriptionLabelTranslated) {
      return this.args.descriptionLabelTranslated;
    } else if (this.args.descriptionLabel) {
      return i18n(this.args.descriptionLabel);
    }
  }

  get tagline() {
    if (this.args.taglineLabelTranslated) {
      return this.args.taglineLabelTranslated;
    } else if (this.args.taglineLabel) {
      return i18n(this.args.taglineLabel);
    }
  }

  <template>
    <div
      class={{concatClass "admin-section-landing-item" (if @icon "-has-icon")}}
      ...attributes
    >
      {{#if @imageUrl}}
        <img class="admin-section-landing-item__image" src={{@imageUrl}} />
      {{/if}}
      {{#if @icon}}
        <div class="admin-section-landing-item__icon">
          {{dIcon @icon}}
        </div>
      {{/if}}
      <div class="admin-section-landing-item__content">
        {{#if this.tagline}}
          <h4 class="admin-section-landing-item__tagline">{{this.tagline}}</h4>
        {{/if}}

        {{#if @titleRoute}}
          <LinkTo @route={{@titleRoute}}><h3
              class="admin-section-landing-item__title"
            >{{this.title}}</h3></LinkTo>
        {{else}}
          <h3 class="admin-section-landing-item__title">{{this.title}}</h3>
        {{/if}}

        <p
          class="admin-section-landing-item__description"
        >{{this.description}}</p>
      </div>

      <div class="admin-section-landing-item__buttons">
        {{yield
          (hash Primary=PrimaryButton Default=DefaultButton Danger=DangerButton)
          to="buttons"
        }}
      </div>
    </div>
  </template>
}
