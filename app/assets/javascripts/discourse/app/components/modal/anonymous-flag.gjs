import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DModal from "discourse/components/d-modal";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class AnonymousFlagModal extends Component {
  @service siteSettings;

  get description() {
    return i18n("anonymous_flagging.description", {
      email: this.#email,
      topic_title: this.args.model.flagModel.topic.title,
      url: getAbsoluteURL(this.args.model.flagModel.url),
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
