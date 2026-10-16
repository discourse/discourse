import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { addToCalendar } from "discourse/lib/download-calendar";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DownloadCalendar extends Component {
  @service currentUser;

  formData = { calendar: "ics", remember: false };
  #formApi;

  @action
  handleSubmit(data) {
    if (data.remember) {
      this.currentUser.set("user_option.default_calendar", data.calendar);
      this.currentUser.save(["default_calendar"]);
    }

    addToCalendar(
      data.calendar,
      this.args.model.calendar.title,
      this.args.model.calendar.dates,
      {
        rrule: this.args.model.calendar.rrule,
        location: this.args.model.calendar.location,
        details: this.args.model.calendar.details,
        timezone: this.args.model.calendar.timezone,
      }
    );
    this.args.closeModal();
  }

  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  @action
  submit() {
    this.#formApi.submit();
  }

  <template>
    <DModal
      class="download-calendar-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "download_calendar.title"}}
    >
      <:body>
        <Form
          @data={{this.formData}}
          @onRegisterApi={{this.registerFormApi}}
          @onSubmit={{this.handleSubmit}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="calendar"
            @title={{i18n "download_calendar.calendar"}}
            @type="radio-group"
            @validation="required"
            as |field|
          >
            <field.Control as |radioGroup|>
              <radioGroup.Radio @value="ics" as |radio|>
                <radio.Title>
                  {{dIcon "download"}}
                  {{i18n "download_calendar.save_ics"}}
                </radio.Title>
              </radioGroup.Radio>
              <radioGroup.Radio @value="google" as |radio|>
                <radio.Title>
                  {{dIcon "fab-google"}}
                  {{i18n "download_calendar.save_google"}}
                </radio.Title>
              </radioGroup.Radio>
              <radioGroup.Radio @value="outlook" as |radio|>
                <radio.Title>
                  {{dIcon "fab-microsoft"}}
                  {{i18n "download_calendar.save_outlook"}}
                </radio.Title>
              </radioGroup.Radio>
              <radioGroup.Radio @value="apple" as |radio|>
                <radio.Title>
                  {{dIcon "fab-apple"}}
                  {{i18n "download_calendar.save_apple"}}
                </radio.Title>
              </radioGroup.Radio>
            </field.Control>
          </form.Field>

          {{#if this.currentUser}}
            <form.Field
              @format="full"
              @name="remember"
              @title={{i18n "download_calendar.remember"}}
              @type="checkbox"
              as |field|
            >
              <field.Control>
                {{i18n "download_calendar.remember_explanation"}}
              </field.Control>
            </form.Field>
          {{/if}}
        </Form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.submit}}
          @label="download_calendar.add_to_calendar"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
