import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import RegionInput from "../../components/region-input";
import { TIME_ZONE_TO_REGION } from "../../lib/regions";

export default class Region extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.discourse_events_enabled;
  }

  @action
  onChange(value) {
    this.args.outletArgs.model.set("custom_fields.holidays-region", value);
  }

  @action
  useCurrentRegion() {
    this.args.outletArgs.model.set(
      "custom_fields.holidays-region",
      TIME_ZONE_TO_REGION[moment.tz.guess()] || "us"
    );
  }

  <template>
    <div class="control-group region">
      <label class="control-label">
        {{i18n "discourse_events.region.title"}}
      </label>

      <div class="controls">
        <RegionInput
          @allowNoneRegion={{true}}
          @onChange={{this.onChange}}
          @value={{@outletArgs.model.custom_fields.holidays-region}}
        />
      </div>

      <DButton
        class="btn-default"
        @action={{this.useCurrentRegion}}
        @icon="globe"
        @label="discourse_events.region.use_current_region"
      />
    </div>
  </template>
}
