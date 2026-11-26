import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import { i18n } from "discourse-i18n";

function join(list, separator) {
  return (list || []).join(separator);
}

// What theme styles may set a variable to, or why they can't change it.
function limits(variable) {
  if (!variable.editable) {
    return i18n("styleguide.sections.design_variables.not_editable", {
      reason: variable.reason,
    });
  }
  if (variable.min_px !== null) {
    return i18n("styleguide.sections.design_variables.length_bounds", {
      min: variable.min_px,
      max: variable.max_px,
    });
  }
  if (variable.keywords) {
    return variable.keywords.join(", ");
  }
  return i18n("styleguide.sections.design_variables.editable");
}

/**
 * Every design variable core defines, read from its compiled CSS, with whether
 * typed theme styles (such as the Admin Assistant's) may change it and within
 * what bounds.
 */
export default class DesignVariables extends Component {
  @tracked filter = "";

  data = ajax("/styleguide/design-variables.json");

  matches = (variable) => {
    const filter = this.filter.trim().toLowerCase();
    return (
      !filter ||
      variable.name.includes(filter) ||
      variable.type.includes(filter) ||
      String(variable.default).toLowerCase().includes(filter)
    );
  };

  @action
  updateFilter(event) {
    this.filter = event.target.value;
  }

  @action
  clearFilter() {
    this.filter = "";
  }

  <template>
    <div class="section-description">
      <p>{{i18n "styleguide.sections.design_variables.description"}}</p>
    </div>

    <DAsyncContent @asyncData={{this.data}}>
      <:content as |result|>
        <DFilterInput
          placeholder={{i18n
            "styleguide.sections.design_variables.filter_placeholder"
          }}
          @containerClass="styleguide-design-variables__filter"
          @filterAction={{this.updateFilter}}
          @icons={{hash left="magnifying-glass"}}
          @onClearInput={{this.clearFilter}}
          @value={{this.filter}}
        />

        <table class="d-table styleguide-design-variables">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "styleguide.sections.design_variables.name"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "styleguide.sections.design_variables.type"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "styleguide.sections.design_variables.default"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "styleguide.sections.design_variables.theme_styles"
                }}</th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each result.design_variables as |variable|}}
              {{#if (this.matches variable)}}
                <tr
                  class="d-table__row styleguide-design-variables__row
                    {{unless variable.editable '--not-editable'}}"
                  data-variable={{variable.name}}
                >
                  <td class="d-table__cell --overview">
                    <code>{{variable.name}}</code>
                    {{#unless (eq variable.scope "root")}}
                      <div class="styleguide-design-variables__scope">
                        {{i18n
                          "styleguide.sections.design_variables.scoped"
                          selectors=(join variable.selectors ", ")
                        }}
                      </div>
                    {{/unless}}
                  </td>
                  <td class="d-table__cell --detail">{{variable.type}}</td>
                  <td class="d-table__cell --detail">
                    <code>{{variable.default}}</code>
                  </td>
                  <td class="d-table__cell --detail">
                    {{limits variable}}
                  </td>
                </tr>
              {{/if}}
            {{/each}}
          </tbody>
        </table>

        <details class="styleguide-design-variables__palette">
          <summary>{{i18n
              "styleguide.sections.design_variables.palette_variables"
              count=result.palette_variables.length
            }}</summary>
          <p>{{i18n
              "styleguide.sections.design_variables.palette_description"
            }}</p>
          <ul>
            {{#each result.palette_variables as |name|}}
              <li><code>{{name}}</code></li>
            {{/each}}
          </ul>
        </details>
      </:content>
    </DAsyncContent>
  </template>
}
