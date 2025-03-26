import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import RadioButton from "discourse/components/radio-button";
import { downloadGoogle, downloadIcs } from "discourse/lib/download-calendar";
import { i18n } from "discourse-i18n";

export default class DownloadCalendar extends Component {
  @service currentUser;

  @tracked selectedCalendar = "ics";
  @tracked remember = false;

  @action
  downloadCalendar() {
    if (this.remember) {
      this.currentUser.set(
        "user_option.default_calendar",
        this.selectedCalendar
      );
      this.currentUser.save(["default_calendar"]);
    }
    if (this.selectedCalendar === "ics") {
      downloadIcs(
        this.args.model.calendar.title,
        this.args.model.calendar.dates,
        {
          recurrenceRule: this.args.model.calendar.recurrenceRule,
          location: this.args.model.calendar.location,
          details: this.args.model.calendar.details,
        }
      );
    } else {
      downloadGoogle(
        this.args.model.calendar.title,
        this.args.model.calendar.dates,
        {
          recurrenceRule: this.args.model.calendar.recurrenceRule,
          location: this.args.model.calendar.location,
          details: this.args.model.calendar.details,
        }
      );
    }
    this.args.closeModal();
  }

  @action
  selectCalendar(calendar) {
    this.selectedCalendar = calendar;
  }

  <template>
    <DModal
      @title={{i18n "download_calendar.title"}}
      class="download-calendar-modal"
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="control-group">
          <div class="ics">
            <label class="radio" for="ics">
              <RadioButton
                id="ics"
                @name="select-calendar"
                @value="ics"
                @selection={{this.selectedCalendar}}
                @onChange={{fn this.selectCalendar "ics"}}
              />
              {{i18n "download_calendar.save_ics"}}
            </label>
          </div>
          <div class="google">
            <label class="radio" for="google">
              <RadioButton
                id="google"
                @name="select-calendar"
                @value="google"
                @selection={{this.selectedCalendar}}
                @onChange={{fn this.selectCalendar "google"}}
              />
              {{i18n "download_calendar.save_google"}}
            </label>
          </div>
        </div>

        {{#if this.currentUser}}
          <div class="control-group remember">
            <label class="checkbox-label">
              <Input @type="checkbox" @checked={{this.remember}} />
              <span>{{i18n "download_calendar.remember"}}</span>
            </label>
            <span>{{i18n "download_calendar.remember_explanation"}}</span>
          </div>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.downloadCalendar}}
          @label="download_calendar.download"
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
