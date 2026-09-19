import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import FilterableList from "../filterable-list";

export default class Form extends Component {
  @service appEvents;

  constructor() {
    super(...arguments);
    if (this.args.closeModal) {
      this.appEvents.on("page:changed", this, this.args.closeModal);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.args.closeModal) {
      this.appEvents.off("page:changed", this, this.args.closeModal);
    }
  }

  <template>
    <DModal
      class="d-templates d-templates-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "templates.insert_template"}}
    >
      <:body>
        <FilterableList
          @onAfterInsertTemplate={{@closeModal}}
          @onInsertTemplate={{@model.onInsertTemplate}}
          @textarea={{@model.textarea}}
        />
      </:body>
    </DModal>
  </template>
}
