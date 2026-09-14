import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import SortableColumn from "./sortable-column";

export default class TopicCell extends Component {
  @service moreTopicsTabs;

  get showTabs() {
    return this.moreTopicsTabs.tabs.length > 1;
  }

  <template>
    {{#if this.showTabs}}
      <th class="topic-list-data default" scope="col">
        <ul class="nav nav-pills">
          {{#each this.moreTopicsTabs.tabs as |tab|}}
            <li>
              <DButton
                class={{dConcatClass
                  "topic-list-header-tab"
                  (if (this.moreTopicsTabs.isActiveTab tab) "active")
                }}
                tabindex={{if (this.moreTopicsTabs.isActiveTab tab) -1 0}}
                @action={{fn this.moreTopicsTabs.selectTab tab}}
                @icon={{tab.icon}}
                @translatedLabel={{tab.name}}
                @translatedTitle={{tab.name}}
              />
            </li>
          {{/each}}
        </ul>
      </th>
    {{else}}
      <SortableColumn
        @activeOrder={{@activeOrder}}
        @ascending={{@ascending}}
        @bulkSelectEnabled={{@bulkSelectEnabled}}
        @bulkSelectHelper={{@bulkSelectHelper}}
        @canBulkSelect={{@canBulkSelect}}
        @canDoBulkActions={{@canDoBulkActions}}
        @category={{@category}}
        @changeSort={{@changeSort}}
        @name={{@name}}
        @order="default"
        @showBulkToggle={{@showBulkToggle}}
      />
    {{/if}}
  </template>
}
