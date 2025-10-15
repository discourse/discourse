import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import AdminFilterControls from "admin/components/admin-filter-controls";

<template>
  <AdminFilterControls
    @array={{@controller.shownTemplates}}
    @searchableProps={{array "title" "id"}}
    @showDropdownFilter={{false}}
    @inputPlaceholder={{i18n
      "admin.customize.email_templates.search_templates"
    }}
    @noResultsMessage={{i18n
      "admin.customize.email_templates.no_templates_found"
    }}
  >
    <:aboveContent>
      <label class="checkbox-label">
        <input
          type="checkbox"
          checked={{@controller.showOverridenOnly}}
          id="toggle-overridden"
          {{on "click" @controller.toggleOverridenOnly}}
        />
        {{i18n "admin.site_text.show_overriden"}}
      </label>
    </:aboveContent>
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
            <tr
              class={{concatClass
                "d-table__row"
                "email-templates-list__row"
                (if template.can_revert "overridden")
              }}
              data-template-id={{template.id}}
            >
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
                    class="btn-default admin-email-templates__edit-button"
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
