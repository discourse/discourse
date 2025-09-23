import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import InfoHeader from "admin/components/form-template/info-header";
import RowItem from "admin/components/form-template/row-item";

export default RouteTemplate(
  <template>
    <div class="form-templates">
      <InfoHeader />

      {{#if @controller.model}}
        <table class="form-templates__table grid">
          <thead>
            <th class="col heading">
              {{i18n "admin.form_templates.list_table.headings.name"}}
            </th>
            <th class="col heading">
              {{i18n
                "admin.form_templates.list_table.headings.active_categories"
              }}
            </th>
            <th class="col heading sr-only">
              {{i18n "admin.form_templates.list_table.headings.actions"}}
            </th>
          </thead>
          <tbody>
            {{#each @controller.model as |template|}}
              <RowItem
                @template={{template}}
                @refreshModel={{@controller.reload}}
              />
            {{/each}}
          </tbody>
        </table>
      {{/if}}

      <DButton
        @label="admin.form_templates.new_template"
        @title="admin.form_templates.new_template"
        @icon="plus"
        @action={{@controller.newTemplate}}
        class="btn-primary"
      />
    </div>
  </template>
);
