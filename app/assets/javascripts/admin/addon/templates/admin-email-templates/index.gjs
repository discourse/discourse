import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import AdminFilterControls from "admin/components/admin-filter-controls";

export default RouteTemplate(
  <template>
    <AdminFilterControls
      @array={{@controller.sortedTemplates}}
      @searchableProps={{array "title" "id"}}
      @showDropdownFilter={{false}}
      @inputPlaceholder={{i18n
        "admin.customize.email_templates.search_templates"
      }}
      @noResultsMessage={{i18n
        "admin.customize.email_templates.no_templates_found"
      }}
    >
      <:content as |filteredTemplates|>
        <table class="d-table email-templates-list">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "admin.customize.email_templates.title"
                }}</th>
              <th class="d-table__header-cell"></th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each filteredTemplates as |template|}}
              <tr class="d-table__row" data-template-id={{template.id}}>
                <td class="d-table__cell --overview">
                  <LinkTo
                    @route="adminEmailTemplates.edit"
                    @model={{template.id}}
                    class="d-table__overview-name admin-email-templates__name"
                  >
                    {{template.title}}
                  </LinkTo>
                </td>
                <td class="d-table__cell --controls">
                  <div class="d-table__cell-actions">
                    <DButton
                      class="admin-email-templates__edit-button"
                      @label="admin.customize.email_templates.edit"
                      @route="adminEmailTemplates.edit"
                      @routeModels={{array template.id}}
                    />
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </:content>
    </AdminFilterControls>
  </template>
);
