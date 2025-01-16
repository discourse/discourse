import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import { getAbsoluteURL } from "discourse/lib/get-url";

export default class AnonymousFlagModal extends Component {
  @service siteSettings;

  get description() {
    return i18n("anonymous_flagging.description", {
      contact_info: `<a href="mailto:${this.#email}?subject=${
        this.#subject
      }&body=${this.#body}">${this.#email}</a>`,
    });
  }

  get #email() {
    if (isEmpty(this.siteSettings.email_address_to_report_illegal_content)) {
      return this.siteSettings.contact_email;
    }
    return this.siteSettings.email_address_to_report_illegal_content;
  }

  get #subject() {
    return i18n("anonymous_flagging.email_subject", {
      title: this.args.model.flagModel.topic.title,
    });
  }
  get #body() {
    return i18n("anonymous_flagging.email_body", {
      url: getAbsoluteURL(this.args.model.flagModel.url),
    });
  }

  <template>
    <DModal
      @title={{i18n "anonymous_flagging.title"}}
      @closeModal={{@closeModal}}
      @bodyClass="anonymous-flag-modal__body"
      class="anonymous-flag-modal"
    >
      <:body>
        {{htmlSafe this.description}}
      </:body>
    </DModal>
  </template>
}
