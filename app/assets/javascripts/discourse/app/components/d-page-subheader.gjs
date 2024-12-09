import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import {
  DangerActionListItem,
  DangerButton,
  DefaultActionListItem,
  DefaultButton,
  PrimaryActionListItem,
  PrimaryButton,
  WrappedActionListItem,
  WrappedButton,
} from "discourse/components/d-page-action-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class DPageSubheader extends Component {
  @service site;

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
    <div class="d-page-subheader">
      <div class="d-page-subheader__title-row">
        <h2 class="d-page-subheader__title">{{this.title}}</h2>
        {{#if (has-block "actions")}}
          <div class="d-page-subheader__actions">
            {{#if this.site.mobileView}}
              <DMenu
                @identifier="d-page-subheader-mobile-actions"
                @title={{i18n "more_options"}}
                @icon="ellipsis-vertical"
                class="btn-small"
              >
                <:content>
                  <DropdownMenu class="d-page-subheader__mobile-actions">
                    {{yield
                      (hash
                        Primary=PrimaryActionListItem
                        Default=DefaultActionListItem
                        Danger=DangerActionListItem
                        Wrapped=WrappedActionListItem
                      )
                      to="actions"
                    }}
                  </DropdownMenu>
                </:content>
              </DMenu>
            {{else}}
              {{yield
                (hash
                  Primary=PrimaryButton
                  Default=DefaultButton
                  Danger=DangerButton
                  Wrapped=WrappedButton
                )
                to="actions"
              }}
            {{/if}}
          </div>
        {{/if}}
      </div>

      {{#if this.description}}
        <p class="d-page-subheader__description">
          {{htmlSafe this.description}}
          {{#if @learnMoreUrl}}
            <span class="d-page-subheader__learn-more">
              {{htmlSafe
                (i18n "learn_more_with_link" url=@learnMoreUrl)
              }}</span>
          {{/if}}
        </p>
      {{/if}}
    </div>
  </template>
}
