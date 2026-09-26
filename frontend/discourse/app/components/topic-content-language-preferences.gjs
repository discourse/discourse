import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import DButton from "discourse/ui-kit/d-button";
import ModalService from "discourse/services/modal";

export default class TopicContentLanguagePreferences extends Component {
  @service(() => ModalService) modal;

  @action
  openPreferences() {
    this.modal.show(
      () => import("discourse/components/modal/content-language-preferences")
    );
  }

  <template>
    <DButton
      class="btn-default topic-content-language-preferences no-text"
      data-test-content-language-preferences
      ...attributes
      @action={{this.openPreferences}}
      @icon="language"
      @title="content_localization.preferences.title"
    />
  </template>
}
