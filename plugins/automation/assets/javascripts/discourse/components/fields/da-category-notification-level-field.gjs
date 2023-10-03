import BaseField from "./da-base-field";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import CategoryNotificationsButton from "select-kit/components/category-notifications-button";
import { hash } from "@ember/helper";

export default class CategoryNotficationLevelField extends BaseField {
  <template>
    <section class="field category-notification-level-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <CategoryNotificationsButton
            @value={{@field.metadata.value}}
            @onChange={{this.mutValue}}
            @options={{hash showFullTitle=true}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
