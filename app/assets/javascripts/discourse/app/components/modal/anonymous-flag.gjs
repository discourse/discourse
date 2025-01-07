import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class AnonymousFlagModal extends Component {
  @service siteSettings;

  get description() {
    return i18n("anonymous_flagging.description", {
      contact_info: `<a href="mailto:${this.#email}?subject=${i18n(
        "anonymous_flagging.illegal_content"
      )}${this.args.model.flagModel.topic.title}">${this.#email}</a>`,
    });
  }

  get #email() {
    if (isEmpty(this.siteSettings.email_address_to_report_illegal_content)) {
      return this.siteSettings.contact_email;
    }
    return this.siteSettings.email_address_to_report_illegal_content;
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
