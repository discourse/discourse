import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class CategoryNotficationLevelField extends BaseField {
  <template>
    <section class="field category-notification-level-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <CategoryNotificationsTracking
            @levelId={{@field.metadata.value}}
            @onChange={{this.mutValue}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
