import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import RegionInput from "../../components/region-input";
import { TIME_ZONE_TO_REGION } from "../../lib/regions";

export default class Region extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.calendar_enabled;
  }

  @tracked _regionValue;

  constructor() {
    super(...arguments);
    this._regionValue =
      this.args.outletArgs?.model?.custom_fields?.["holidays-region"];
  }

  @action
  updateRegion(value) {
    this._regionValue = value;
    const form = this.args.outletArgs?.form;
    if (form?.set) {
      form.set("custom_fields.holidays-region", value);
    }
  }

  @action
  useCurrentRegion() {
    const value = TIME_ZONE_TO_REGION[moment.tz.guess()] || "us";
    this._regionValue = value;
    const form = this.args.outletArgs?.form;
    if (form?.set) {
      form.set("custom_fields.holidays-region", value);
    }
  }

  get regionValue() {
    return this._regionValue;
  }

  <template>
    <@form.Field
      @name={{i18n "discourse_calendar.region.title"}}
      @title={{i18n "discourse_calendar.region.title"}}
      as |field|
    >
      <field.Custom>
        <RegionInput
          @value={{this.regionValue}}
          @allowNoneRegion={{true}}
          @onChange={{this.updateRegion}}
        />
        <DButton
          @icon="globe"
          @label="discourse_calendar.region.use_current_region"
          @action={{this.useCurrentRegion}}
        />
      </field.Custom>
    </@form.Field>
  </template>
}
