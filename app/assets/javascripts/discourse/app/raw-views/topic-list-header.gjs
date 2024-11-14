import { cached } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { createColumns } from "discourse/components/topic-list/dag";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class TopicListHeader extends EmberObject {
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
      "topic-list-header-columns",
      createColumns(),
      context
    )
      .resolve()
      .map((entry) => {
        if (entry.value?.header) {
          return htmlSafe(
            rawRenderGlimmer(
              this,
              "th.hbr-ember-outlet",
              <template>
                <@data.component
                  @sortable={{@data.sortable}}
                  @activeOrder={{@data.order}}
                  @changeSort={{@data.changeSort}}
                  @ascending={{@data.ascending}}
                  @category={{@data.category}}
                  @name={{@data.listTitle}}
                  @bulkSelectEnabled={{@data.bulkSelectEnabled}}
                  @showBulkToggle={{@data.toggleInTitle}}
                  @canBulkSelect={{@data.canBulkSelect}}
                  @canDoBulkActions={{@data.canDoBulkActions}}
                  @showTopicsAndRepliesToggle={{@data.showTopicsAndRepliesToggle}}
                  @newListSubset={{@data.newListSubset}}
                  @newRepliesCount={{@data.newRepliesCount}}
                  @newTopicsCount={{@data.newTopicsCount}}
                  @bulkSelectHelper={{@data.bulkSelectHelper}}
                  @changeNewListSubset={{@data.changeNewListSubset}}
                  @showPosters={{@data.showPosters}}
                  @showLikes={{@data.showLikes}}
                  @showOpLikes={{@data.showOpLikes}}
                />
              </template>,
              {
                component: entry.value.header,
                sortable: this.sortable,
                order: this.order,
                changeSort: this.changeSort,
                ascending: this.ascending,
                category: this.topicTrackingState.filterCategory,
                listTitle: this.listTitle,
                bulkSelectEnabled: this.bulkSelectEnabled,
                toggleInTitle: this.toggleInTitle,
                canBulkSelect: this.canBulkSelect,
                canDoBulkActions: this.canDoBulkActions,
                showTopicsAndRepliesToggle: this.showTopicsAndRepliesToggle,
                newListSubset: this.newListSubset,
                newRepliesCount: this.newRepliesCount,
                newTopicsCount: this.newTopicsCount,
                bulkSelectHelper: this.bulkSelectHelper,
                changeNewListSubset: this.changeNewListSubset,
                showPosters: this.showPosters,
                showLikes: this.showLikes,
                showOpLikes: this.showOpLikes,
              }
            )
          );
        }
      });
  }
}
