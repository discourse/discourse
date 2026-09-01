import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ContentLanguagePreferencesModal from "discourse/components/modal/content-language-preferences";
import DButton from "discourse/ui-kit/d-button";

export default class TopicContentLanguagePreferences extends Component {
  @service modal;

  @action
  openPreferences() {
    this.modal.show(ContentLanguagePreferencesModal);
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
