import Component from "@glimmer/component";
import { service } from "@ember/service";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class AnonymousFlagModal extends Component {
  @service siteSettings;

  <template>
    <DModal
      class="anonymous-flag-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "anonymous_flagging.title"}}
    >
      <:body>
        <DInterpolatedTranslation
          @key="flagging.illegal_reporting"
          as |Placeholder|
        >
          <Placeholder @name="form">
            <a
              href={{this.siteSettings.illegal_content_reporting_url}}
              rel="noopener noreferrer"
              target="_blank"
            >{{i18n "flagging.illegal_reporting_form"}}</a>
          </Placeholder>
        </DInterpolatedTranslation>
      </:body>
    </DModal>
  </template>
}
