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
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      <div class="workflows-property-engine__select-with-action">
        <DynamicOptionsComboBox
          @content={{this.options}}
          @loadOptions={{if this.usesRemoteOptions this.loadRemoteOptions}}
          @nameProperty="name"
          @onChange={{this.handleChange}}
          @options={{hash
            filterable=this.filterable
            none=this.none
            castInteger=this.castInteger
          }}
          @value={{@field.value}}
          @valueProperty="id"
        />
        {{#unless @field.value}}
          <DButton
            class="btn-default"
            @action={{this.manageDataTables}}
            @icon="plus"
            @label="discourse_workflows.data_tables.manage_data_tables"
          />
        {{/unless}}
      </div>
    </ExpressionWrapper>
  </template>
}
