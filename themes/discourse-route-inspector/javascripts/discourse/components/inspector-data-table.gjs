import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import InspectorKey from "./inspector-key";
import InspectorValue from "./inspector-value";

export default class InspectorDataTable extends Component {
  @service routeInspectorState;

  get emptyData() {
    return !this.args.data || Object.keys(this.args.data).length === 0;
  }

  get currentFilter() {
    return { query: this.routeInspectorState.filter, caseSensitive: false };
  }

  get filteredData() {
    if (!this.args.data) {
      return {};
    }
    // In detail view, filter out internal keys for param types
    if (this.args.isDetailView) {
      const filtered = {};
      for (const [key, value] of Object.entries(this.args.data)) {
        // Skip internal keys used for param type metadata
        if (key === "_type" || key === "_data") {
          continue;
        }
        filtered[key] = value;
      }
      return filtered;
    }
    return this.args.data;
  }

  <template>
    <div class="inspector-data-table-wrapper">
      <table class="inspector-data-table">
        <tbody>
          {{#each-in this.filteredData as |key value|}}
            <tr>
              <td class="inspector-data-table__key" title={{key}}>
                <InspectorKey
                  @value={{key}}
                  @valueData={{value}}
                  @hoverable={{true}}
                  @copyable={{true}}
                  @filter={{this.currentFilter}}
                />
              </td>
              <td class="inspector-data-table__value">
                <InspectorValue
                  @value={{value}}
                  @onDrillInto={{fn @onDrillInto key value}}
                  @filter={{this.currentFilter}}
                  @isDetailView={{@isDetailView}}
                  @isSimpleDetailsView={{@isSimpleDetailsView}}
                />
              </td>
            </tr>
          {{/each-in}}
          {{#if this.emptyData}}
            <tr>
              <td colspan="2" class="inspector-data-table__empty">
                {{#if this.currentFilter.query}}
                  {{i18n (themePrefix "route_inspector.content.no_matches")}}
                {{else}}
                  {{i18n (themePrefix "route_inspector.content.empty")}}
                {{/if}}
              </td>
            </tr>
          {{/if}}
        </tbody>
      </table>
    </div>
  </template>
}
