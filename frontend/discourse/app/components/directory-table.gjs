import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DirectoryItem from "discourse/components/directory-item";
import directoryColumnIsAutomatic from "discourse/helpers/directory-column-is-automatic";
import DResponsiveTable from "discourse/ui-kit/d-responsive-table";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import { i18n } from "discourse-i18n";

export default class DirectoryTable extends Component {
  table;

  @action
  setupTable(element) {
    this.table = element.querySelector(".directory-table");
    const columnCount = this.args.showTimeRead
      ? this.args.columns.length + 1
      : this.args.columns.length;

    this.table.style.gridTemplateColumns = `minmax(15em, 3fr) repeat(${columnCount}, minmax(max-content, 1fr))`;
  }

  @action
  updateOrderAndAsc(field, asc) {
    this.args.updateOrderAndAsc(field, asc);
  }

  <template>
    <DResponsiveTable {{didInsert this.setupTable}}>
      <:header>
        <DTableHeaderToggle @field="username" @order={{@order}} @asc={{@asc}} />
        {{#each @columns as |column|}}
          <DTableHeaderToggle
            @onToggle={{this.updateOrderAndAsc}}
            @field={{column.name}}
            @icon={{column.icon}}
            @order={{@order}}
            @asc={{@asc}}
            @automatic={{directoryColumnIsAutomatic column=column}}
            @translated={{column.user_field_id}}
          />
        {{/each}}

        {{#if @showTimeRead}}
          <div class="directory-table__column-header">
            <div class="header-contents">
              {{i18n "directory.time_read"}}
            </div>
          </div>
        {{/if}}
      </:header>

      <:body>
        {{#each @items as |item|}}
          <DirectoryItem
            @item={{item}}
            @columns={{@columns}}
            @showTimeRead={{@showTimeRead}}
          />
        {{/each}}
      </:body>
    </DResponsiveTable>
  </template>
}
