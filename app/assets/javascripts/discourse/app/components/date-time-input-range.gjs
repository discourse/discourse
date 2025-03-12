<DateTimeInput
  @date={{this.from}}
  @onChange={{action "onChangeRanges" (hash prop="from")}}
  @showTime={{this.showFromTime}}
  @placeholder={{i18n "dates.from_placeholder"}}
  @timezone={{@timezone}}
  class="from"
/>

<DateTimeInput
  @date={{this.to}}
  @relativeDate={{this.from}}
  @onChange={{action "onChangeRanges" (hash prop="to")}}
  @timeFirst={{this.toTimeFirst}}
  @showTime={{this.showToTime}}
  @clearable={{this.clearable}}
  @placeholder={{i18n "dates.to_placeholder"}}
  @timezone={{@timezone}}
  class="to"
/>