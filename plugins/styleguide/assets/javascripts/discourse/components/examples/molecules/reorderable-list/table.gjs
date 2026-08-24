import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

export default class ReorderableListTableExample extends Component {
  fields = trackedArray([
    { id: "name", name: "Full name", type: "Text" },
    { id: "location", name: "Location", type: "Text" },
    { id: "website", name: "Website", type: "URL" },
  ]);

  fieldLabel = (item) => item.name;

  @action
  applyMove({ proposedToItems }) {
    this.fields.splice(0, this.fields.length, ...proposedToItems);
  }

  <template>
    {{! The reorderable list renders the tbody itself, which the static
        table-group rule cannot see from here. }}
    {{! eslint-disable-next-line ember/template-table-groups }}
    <table class="styleguide-reorderable-table">
      <thead>
        <tr>
          <th></th>
          <th>{{i18n "styleguide.sections.reorderable_list.table_field"}}</th>
          <th>{{i18n "styleguide.sections.reorderable_list.table_type"}}</th>
        </tr>
      </thead>
      <DReorderableList
        @items={{this.fields}}
        @key="id"
        @label={{this.fieldLabel}}
        @onMove={{this.applyMove}}
        @controls="manual"
        @tag="tbody"
        @itemTag="tr"
      >
        <:row as |item row|>
          <td class="styleguide-reorderable-table__reorder">
            <row.handle />
          </td>
          <td>{{item.name}}</td>
          <td>{{item.type}}</td>
        </:row>
      </DReorderableList>
    </table>
  </template>
}
