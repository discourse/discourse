import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import EventRegistrationFormEditor from "discourse/plugins/discourse-events/discourse/components/event-registration-form-editor";

export default class RegistrationFormEditor extends Component {
  @service router;

  @tracked cardElement;

  @action
  registerCard(element) {
    this.cardElement = element;
  }

  @action
  returnToLibrary() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-events-registration-forms.index"
    );
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-events-registration-forms.index"
    />
    <AdminConfigAreaCard
      class="event-registration-form-editor"
      @heading={{if
        @record.id
        "event_registration.library.edit"
        "event_registration.library.new"
      }}
      {{didInsert this.registerCard}}
    >
      <:content>
        <EventRegistrationFormEditor
          @actionsWidthSource={{this.cardElement}}
          @onFinished={{this.returnToLibrary}}
          @record={{@record}}
        />
      </:content>
    </AdminConfigAreaCard>
  </template>
}
