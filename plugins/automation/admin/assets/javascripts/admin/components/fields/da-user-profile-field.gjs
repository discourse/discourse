import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import MultiSelect from "discourse/select-kit/components/multi-select";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class UserProfileField extends BaseField {
  @tracked allProfileFields = [];

  userProfileFields = [
    "bio_raw",
    "website",
    "location",
    "date_of_birth",
    "timezone",
  ];

  <template>
    <section class="field group-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />
        <div class="controls">
          <MultiSelect
            @content={{this.userProfileFields}}
            @nameProperty={{null}}
            @onChange={{this.mutValue}}
            @options={{hash allowAny=true disabled=@field.isDisabled}}
            @value={{@field.metadata.value}}
            @valueProperty={{null}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
