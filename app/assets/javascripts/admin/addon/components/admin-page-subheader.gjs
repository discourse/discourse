import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import i18n from "discourse-common/helpers/i18n";
import {
  DangerButton,
  DefaultButton,
  PrimaryButton,
} from "admin/components/admin-page-action-button";

export default class AdminPageSubheader extends Component {
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

  <template>
    <div class="admin-page-subheader">
      <div class="admin-page-subheader__title-row">
        <h3 class="admin-page-subheader__title">{{this.title}}</h3>
        <div class="admin-page-subheader__actions">
          {{yield
            (hash
              Primary=PrimaryButton Default=DefaultButton Danger=DangerButton
            )
            to="actions"
          }}
        </div>
      </div>

      {{#if this.description}}
        <p class="admin-page-subheader__description">
          {{htmlSafe this.description}}
          {{#if @learnMoreUrl}}
            <span class="admin-page-subheader__learn-more">
              {{htmlSafe
                (i18n "learn_more_with_link" url=@learnMoreUrl)
              }}</span>
          {{/if}}
        </p>
      {{/if}}
    </div>
  </template>
}
