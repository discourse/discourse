import InfoHeader from "discourse/admin/components/form-template/info-header";
import RowItem from "discourse/admin/components/form-template/row-item";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
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
              @refreshModel={{@controller.reload}}
              @template={{template}}
            />
          {{/each}}
        </tbody>
      </table>
    {{/if}}

    <DButton
      class="btn-primary"
      @action={{@controller.newTemplate}}
      @icon="plus"
      @label="admin.form_templates.new_template"
      @title="admin.form_templates.new_template"
    />
  </div>
</template>
