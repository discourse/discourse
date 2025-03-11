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