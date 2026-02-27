import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import SortableColumn from "./sortable-column";

export default class TopicCell extends Component {
  @service moreTopicsTabs;

  get showTabs() {
    return this.moreTopicsTabs.tabs.length > 1;
  }

  <template>
    {{#if this.showTabs}}
      <th scope="col" class="topic-list-data default">
        <ul class="nav nav-pills">
          {{#each this.moreTopicsTabs.tabs as |tab|}}
            <li>
              <DButton
                @action={{fn this.moreTopicsTabs.selectTab tab}}
                @translatedLabel={{tab.name}}
                @translatedTitle={{tab.name}}
                @icon={{tab.icon}}
                class={{if (this.moreTopicsTabs.isActiveTab tab) "active"}}
                tabindex={{if (this.moreTopicsTabs.isActiveTab tab) -1 0}}
              />
            </li>
          {{/each}}
        </ul>
      </th>
    {{else}}
      <SortableColumn
        @order="default"
        @category={{@category}}
        @activeOrder={{@activeOrder}}
        @changeSort={{@changeSort}}
        @ascending={{@ascending}}
        @name={{@name}}
        @bulkSelectEnabled={{@bulkSelectEnabled}}
        @showBulkToggle={{@showBulkToggle}}
        @canBulkSelect={{@canBulkSelect}}
        @canDoBulkActions={{@canDoBulkActions}}
        @bulkSelectHelper={{@bulkSelectHelper}}
      />
    {{/if}}
  </template>
}
