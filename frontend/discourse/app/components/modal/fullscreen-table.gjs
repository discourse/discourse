import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class FullscreenTable extends Component {
  tablePlaceholder;

  willDestroy() {
    super.willDestroy(...arguments);
    this.tablePlaceholder?.replaceWith(this.args.model.table);
  }

  @action
  mountTable(element) {
    const table = this.args.model.table;
    this.tablePlaceholder = document.createComment("fullscreen table");
    table.replaceWith(this.tablePlaceholder);
    element.appendChild(table);
  }

  <template>
    <DModal
      class="fullscreen-table-modal --max"
      @closeModal={{@closeModal}}
      @title={{i18n "fullscreen_table.view_table"}}
    >
      <:body>
        <div
          class="cooked {{if @model.displayFootnotesInline 'inline-footnotes'}}"
          data-ref-post-id={{@model.postId}}
          {{didInsert this.mountTable}}
        ></div>
      </:body>
    </DModal>
  </template>
}
