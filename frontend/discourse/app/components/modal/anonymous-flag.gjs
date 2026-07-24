import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { getAbsoluteURL } from "discourse/lib/get-url";
import DModal from "discourse/ui-kit/d-modal";
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
        <p>{{trustHTML (i18n "flagging.review_process_description")}}</p>
        <p>{{trustHTML this.description}}</p>
      </:body>
    </DModal>
  </template>
}
