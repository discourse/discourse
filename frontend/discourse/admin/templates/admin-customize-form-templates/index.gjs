import InfoHeader from "discourse/admin/components/form-template/info-header";
import RowItem from "discourse/admin/components/form-template/row-item";
import DButton from "discourse/components/d-button";
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
