import BackButton from "discourse/components/back-button";
import { i18n } from "discourse-i18n";
import EventRegistrationFormEditor from "../components/event-registration-form-editor.gjs";

export default <template>
  <section class="event-registration-form-page">
    <BackButton
      @label="event_registration.library.manage"
      @route="my-event-registration-forms"
    />
    <h1>{{i18n "event_registration.library.new"}}</h1>
    <EventRegistrationFormEditor @record={{@model}} as |title|>
      <p class="alert alert-success" role="status">
        {{i18n "event_registration.created_for_event" title=title}}
      </p>
    </EventRegistrationFormEditor>
  </section>
</template>
