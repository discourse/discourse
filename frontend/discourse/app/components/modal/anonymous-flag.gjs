import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import getFlagContentUrl from "discourse/lib/get-flag-content-url";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class AnonymousFlagModal extends Component {
  @service siteSettings;

  get description() {
    return this.args.model.flagTarget.anonymousFlagDescription(
      this.args.model.flagModel,
      this.#email
    );
  }

  get #email() {
    if (isEmpty(this.siteSettings.email_address_to_report_illegal_content)) {
      return this.siteSettings.contact_email;
    }
    return this.siteSettings.email_address_to_report_illegal_content;
  }

  <template>
    <DModal
      class="anonymous-flag-modal"
      @bodyClass="anonymous-flag-modal__body"
      @closeModal={{@closeModal}}
      @title={{i18n "anonymous_flagging.title"}}
    >
      <:body>
        {{#if this.siteSettings.dsa_reporting_enabled}}
          <p class="anonymous-flag-modal__dsa-description">
            <DInterpolatedTranslation
              @key="anonymous_flagging.dsa_description"
              as |Placeholder|
            >
              <Placeholder @name="reportLink">
                <LinkTo
                  class="anonymous-flag-modal__report-illegal-content"
                  @query={{hash
                    content_url=(getFlagContentUrl @model.flagModel)
                  }}
                  @route="report-illegal-content"
                  {{on "click" @closeModal}}
                >
                  {{i18n "anonymous_flagging.report_link"}}
                </LinkTo>
              </Placeholder>
            </DInterpolatedTranslation>
          </p>
        {{else}}
          <p>{{trustHTML (i18n "flagging.review_process_description")}}</p>
          <p>{{trustHTML this.description}}</p>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
