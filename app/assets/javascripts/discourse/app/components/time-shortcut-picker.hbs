<TapTileGrid @activeTile={{this.selectedShortcut}} as |grid|>
  {{#each this.options key="id" as |option|}}
    {{#unless option.hidden}}
      <TapTile
        @tileId={{option.id}}
        @activeTile={{grid.activeTile}}
        @onChange={{action "selectShortcut"}}
      >

        <div class="tap-tile-title">{{i18n option.label}}</div>
        <div class="tap-tile-date">{{option.timeFormatted}}</div>
      </TapTile>
    {{/unless}}

    {{#if option.isCustomTimeShortcut}}
      {{#if this.customDatetimeSelected}}
        <div class="control-group custom-date-time-wrap custom-input-wrap">
          <div class="tap-tile-date-input">
            {{d-icon "calendar-days"}}
            <DatePickerFuture
              @value={{this.customDate}}
              @defaultDate={{this.defaultCustomDate}}
              @onSelect={{fn (mut this.customDate)}}
              @id="custom-date"
            />
          </div>
          <div class="tap-tile-time-input">
            {{d-icon "far-clock"}}
            <Input
              placeholder="--:--"
              id="custom-time"
              @type="time"
              class="time-input"
              @value={{this.customTime}}
            />
          </div>
        </div>
        <div class="control-group custom-date-time-wrap custom-relative-wrap">
          <label class="control-label" for="bookmark-relative-time-picker">
            {{i18n "relative_time_picker.relative"}}
          </label>
          <RelativeTimePicker
            @durationMinutes={{this.selectedDurationMins}}
            @onChange={{this.relativeTimeChanged}}
            id="bookmark-relative-time-picker"
          />
        </div>
      {{/if}}
    {{/if}}
  {{/each}}
</TapTileGrid>