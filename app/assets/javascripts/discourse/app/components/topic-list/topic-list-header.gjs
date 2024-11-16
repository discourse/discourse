import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { applyValueTransformer } from "discourse/lib/transformer";
import { createColumns } from "./dag";

export default class TopicListHeader extends Component {
  @service topicTrackingState;

  @cached
  get columns() {
    const self = this;
    const context = {
      get category() {
        return self.topicTrackingState.get("filterCategory");
      },

      get filter() {
        return self.topicTrackingState.get("filter");
      },
    };

    return applyValueTransformer(
      "topic-list-columns",
      createColumns(),
      context
    );
  }

  <template>
    <tr>
      {{#each (this.columns.resolve) as |entry|}}
        {{#if entry.value.header}}
          <entry.value.header
            @sortable={{@sortable}}
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
            @showPosters={{@showPosters}}
            @showLikes={{@showLikes}}
            @showOpLikes={{@showOpLikes}}
          />
        {{/if}}
      {{/each}}
    </tr>
  </template>
}
