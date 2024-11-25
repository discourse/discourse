import Component from "@glimmer/component";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class Header extends Component {
  get sortable() {
    return applyValueTransformer(
      "topic-list-header-sortable-column",
      this.args.sortable,
      {
        category: this.args.category,
        name: this.args.name,
      }
    );
  }

  <template>
    <tr>
      {{#each @columns as |entry|}}
        <entry.value.header
          @sortable={{this.sortable}}
          @activeOrder={{@order}}
          @changeSort={{@changeSort}}
          @ascending={{@ascending}}
          @category={{@category}}
          @name={{@listTitle}}
          @bulkSelectEnabled={{@bulkSelectEnabled}}
          @showBulkToggle={{@toggleInTitle}}
          @canBulkSelect={{@canBulkSelect}}
          @canDoBulkActions={{@canDoBulkActions}}
          @showTopicsAndRepliesToggle={{@showTopicsAndRepliesToggle}}
          @newListSubset={{@newListSubset}}
          @newRepliesCount={{@newRepliesCount}}
          @newTopicsCount={{@newTopicsCount}}
          @bulkSelectHelper={{@bulkSelectHelper}}
          @changeNewListSubset={{@changeNewListSubset}}
        />
      {{/each}}
    </tr>
  </template>
}
