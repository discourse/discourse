import { hash } from "@ember/helper";
import CategoryNotificationsButton from "select-kit/components/category-notifications-button";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

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
