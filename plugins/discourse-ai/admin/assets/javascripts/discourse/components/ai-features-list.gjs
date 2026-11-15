import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import AiFeaturesModuleRow from "./ai-features-module-row.gjs";

export default class AiFeaturesList extends Component {
  get sortedModules() {
    return (this.args.modules || []).toSorted((a, b) =>
      this.#moduleName(a).localeCompare(this.#moduleName(b))
    );
  }

  #moduleName(aModule) {
    return i18n(`discourse_ai.features.${aModule.module_name}.name`);
  }

  <template>
    <table class="d-table ai-features-list">
      <thead class="d-table__header">
        <tr class="d-table__row">
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.table.module"}}
          </th>
          <th class="d-table__header-cell">
            {{i18n "discourse_ai.features.table.status"}}
          </th>
          <th class="d-table__header-cell"><span class="sr-only">{{i18n
                "discourse_ai.features.table.enabled"
              }}</span></th>
          <th class="d-table__header-cell"><span class="sr-only">{{i18n
                "actions"
              }}</span></th>
        </tr>
      </thead>
      <tbody class="d-table__body">
        {{#each this.sortedModules key="id" as |module|}}
          <AiFeaturesModuleRow
            @enabled={{module.module_enabled}}
            @enabledSetting={{module.enabled_setting}}
            @features={{module.features}}
            @forceExpanded={{@expandAll}}
            @modelNames={{module.model_names}}
            @module={{module}}
            @onChange={{@onChange}}
            @status={{module.status}}
          />
        {{/each}}
      </tbody>
    </table>
  </template>
}
