import BaseField from "./da-base-field";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { tracked } from "@glimmer/tracking";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import ComboBox from "select-kit/components/combo-box";
import { hash } from "@ember/helper";
import { inject as service } from "@ember/service";

export default class GroupField extends BaseField {
  <template>
    <section class="field group-field" {{didInsert this.loadUserFields}}>
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <ComboBox
            @content={{this.allCustomFields}}
            @value={{@field.metadata.value}}
            @onChange={{this.mutValue}}
          />
          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @service store;
  @tracked allCustomFields = [];

  @bind
  loadUserFields() {
    this.store.findAll("user-field").then((fields) => {
      this.allCustomFields = fields.content;
    });
  }
}
