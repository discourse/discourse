import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
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
      @closeModal={{@closeModal}}
      @title={{i18n "templates.insert_template"}}
      class="d-templates d-templates-modal"
    >
      <:body>
        <FilterableList
          @textarea={{@model.textarea}}
          @onInsertTemplate={{@model.onInsertTemplate}}
          @onAfterInsertTemplate={{@closeModal}}
        />
      </:body>
    </DModal>
  </template>
}
