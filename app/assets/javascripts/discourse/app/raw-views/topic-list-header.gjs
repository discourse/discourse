import { cached } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import EmberObject from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { createColumns } from "discourse/components/topic-list/topic-list-header";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class TopicListHeader extends EmberObject {
  @service topicTrackingState;
  @controller("discovery/list") discoveryListController;

  @cached
  get columns() {
    const self = this;
    const context = {
      get category() {
        return self.topicTrackingState.filterCategory;
      },

      get filter() {
        return self.topicTrackingState.filter;
      },
    };

    return applyValueTransformer(
      "topic-list-header-columns",
      createColumns(),
      context
    )
      .resolve()
      .map((entry) => {
        if (entry.value) {
          entry.value = htmlSafe(
            rawRenderGlimmer(
              this,
              "th.hbr-ember-outlet",
              <template>
                <@data.component
                  @sortable={{@data.sortable}}
                  @order={{@data.order}}
                  @changeSort={{@data.changeSort}}
                  @ascending={{@data.ascending}}
                  @category={{@data.category}}
                  @listTitle={{@data.listTitle}}
                  @bulkSelectEnabled={{@data.bulkSelectEnabled}}
                  @toggleInTitle={{@data.toggleInTitle}}
                  @canBulkSelect={{@data.canBulkSelect}}
                  @canDoBulkActions={{@data.canDoBulkActions}}
                  @showTopicsAndRepliesToggle={{@data.showTopicsAndRepliesToggle}}
                  @newListSubset={{@data.newListSubset}}
                  @newRepliesCount={{@data.newRepliesCount}}
                  @newTopicsCount={{@data.newTopicsCount}}
                  @bulkSelectHelper={{@data.bulkSelectHelper}}
                  @changeNewListSubset={{@data.changeNewListSubset}}
                />
              </template>,
              {
                component: entry.value,
                sortable: this.sortable,
                order: this.order,
                changeSort: this.discoveryListController.changeSort,
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
                changeNewListSubset:
                  this.discoveryListController.changeNewListSubset,
              }
            )
          );
        }

        return entry;
      });
  }
}
