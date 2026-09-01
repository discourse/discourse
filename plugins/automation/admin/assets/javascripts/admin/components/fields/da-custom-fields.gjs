import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import MultiSelect from "discourse/select-kit/components/multi-select";
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
          <MultiSelect
            @content={{this.allCustomFields}}
            @nameProperty={{null}}
            @onChange={{this.mutValue}}
            @options={{hash allowAny=false disabled=@field.isDisabled}}
            @value={{@field.metadata.value}}
            @valueProperty={{null}}
          />
          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @bind
  loadUserFields() {
    this.store.findAll("user-field").then((fields) => {
      this.allCustomFields = fields.content.map((field) => field.name);
    });
  }
}
