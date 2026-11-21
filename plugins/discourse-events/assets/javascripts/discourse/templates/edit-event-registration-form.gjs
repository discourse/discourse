import BackButton from "discourse/components/back-button";
import { i18n } from "discourse-i18n";
import EventRegistrationFormEditor from "../components/event-registration-form-editor.gjs";

export default <template>
  <section class="event-registration-form-page">
    <BackButton @route="my-event-registration-forms" />
    <h1>{{i18n "event_registration.library.edit"}}</h1>
    <EventRegistrationFormEditor
      @onFinished={{@controller.returnToForms}}
      @record={{@model}}
    />
  </section>
</template>
