import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import ComboBox from "discourse/select-kit/components/combo-box";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class GroupField extends BaseField {
  @service store;

  @tracked allCustomFields = [];

  <template>
    <section class="field group-field" {{didInsert this.loadUserFields}}>
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <ComboBox
            @content={{this.allCustomFields}}
            @onChange={{this.mutValue}}
            @value={{@field.metadata.value}}
          />
          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @bind
  loadUserFields() {
    this.store.findAll("user-field").then((fields) => {
      this.allCustomFields = fields.content;
    });
  }
}
