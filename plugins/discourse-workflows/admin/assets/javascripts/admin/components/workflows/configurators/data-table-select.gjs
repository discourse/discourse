import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ComboBoxField, { DynamicOptionsComboBox } from "./combo-box";
import ExpressionWrapper from "./expression-wrapper";

export default class DataTableSelect extends ComboBoxField {
  @service router;

  @action
  manageDataTables() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-workflows-data-tables"
    );
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      <div class="workflows-property-engine__select-with-action">
        <DynamicOptionsComboBox
          @content={{this.options}}
          @loadOptions={{if this.usesRemoteOptions this.loadRemoteOptions}}
          @nameProperty="name"
          @value={{@field.value}}
          @valueProperty="id"
          @onChange={{this.handleChange}}
          @options={{hash
            filterable=this.filterable
            none=this.none
            castInteger=this.castInteger
          }}
        />
        {{#unless @field.value}}
          <DButton
            @action={{this.manageDataTables}}
            @label="discourse_workflows.data_tables.manage_data_tables"
            @icon="plus"
            class="btn-default"
          />
        {{/unless}}
      </div>
    </ExpressionWrapper>
  </template>
}
