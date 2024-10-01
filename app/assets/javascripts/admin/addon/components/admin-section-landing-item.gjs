import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import {
  DangerButton,
  DefaultButton,
  PrimaryButton,
} from "admin/components/admin-page-action-button";

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

  get subTitle() {
    if (this.args.subTitleLabelTranslated) {
      return this.args.subTitleLabelTranslated;
    } else if (this.args.subTitleLabel) {
      return i18n(this.args.subTitleLabel);
    }
  }

  get cssClasses() {
    const classes = ["admin-section-landing-item"];
    if (this.args.icon) {
      classes.push("-has-icon");
    }
    return classes.join(" ");
  }

  <template>
    <div class={{this.cssClasses}} ...attributes>
      {{#if @imageUrl}}
        <img class="admin-section-landing-item__image" src={{@imageUrl}} />
      {{/if}}
      {{#if @icon}}
        <div class="admin-section-landing-item__icon">
          {{dIcon @icon}}
        </div>
      {{/if}}
      <div class="admin-section-landing-item__content">
        {{#if this.subTitle}}
          <h4
            class="admin-section-landing-item__subtitle"
          >{{this.subTitle}}</h4>
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
