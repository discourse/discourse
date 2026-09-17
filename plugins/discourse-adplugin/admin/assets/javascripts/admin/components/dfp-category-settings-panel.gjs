import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const PATH = "/admin/plugins/discourse-adplugin/dfp-settings";

export default class DfpCategorySettingsPanel extends Component {
  @service site;
  @service toasts;

  @tracked rows = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.refresh();
  }

  get categories() {
    return this.site.categories;
  }

  async refresh() {
    try {
      const data = await ajax(PATH);
      this.rows = (data.dfp_category_settings || []).map((setting) => ({
        ...setting,
        isNew: false,
      }));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  replaceRow(row, updated) {
    this.rows = this.rows.map((r) => (r === row ? updated : r));
  }

  @action
  addRow() {
    this.rows = [
      {
        id: null,
        category_id: null,
        gam_adunit: null,
        gam_keywords: null,
        gtm_taxonomy: null,
        isNew: true,
      },
      ...this.rows,
    ];
  }

  @action
  setCategory(row, categoryId) {
    this.replaceRow(row, { ...row, category_id: categoryId });
  }

  @action
  setField(row, field, event) {
    const value = event.target.value;
    this.replaceRow(row, { ...row, [field]: value });
  }

  @action
  async save(row) {
    const payload = {
      category_id: row.category_id,
      gam_adunit: row.gam_adunit,
      gam_keywords: row.gam_keywords,
      gtm_taxonomy: row.gtm_taxonomy,
    };

    try {
      const result = await ajax(row.isNew ? PATH : `${PATH}/${row.id}`, {
        type: row.isNew ? "POST" : "PUT",
        data: payload,
      });

      this.replaceRow(row, { ...result.dfp_category_setting, isNew: false });
      this.toasts.success({
        data: { message: i18n("saved") },
        duration: "short",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async destroy(row) {
    if (row.isNew) {
      this.rows = this.rows.filter((r) => r !== row);
      return;
    }

    try {
      await ajax(`${PATH}/${row.id}`, { type: "DELETE" });
      this.rows = this.rows.filter((r) => r !== row);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#if this.loading}}
      <div class="dfp-settings-table__loading">
        {{i18n "admin.adplugin.dfp_settings.loading"}}
      </div>
    {{else}}
      <table class="d-table dfp-settings-table">
        <thead class="d-table__header">
          <tr>
            <th>{{i18n "admin.adplugin.dfp_settings.category"}}</th>
            <th>{{i18n "admin.adplugin.dfp_settings.gam_adunit"}}</th>
            <th>{{i18n "admin.adplugin.dfp_settings.gam_keywords"}}</th>
            <th>{{i18n "admin.adplugin.dfp_settings.gtm_taxonomy"}}</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {{#each this.rows as |row|}}
            <tr class="d-table__row dfp-settings-table__row">
              <td class="d-table__cell dfp-settings-table__category">
                <ComboBox
                  @content={{this.categories}}
                  @nameProperty="name"
                  @onChange={{fn this.setCategory row}}
                  @value={{row.category_id}}
                  @valueProperty="id"
                />
              </td>
              <td class="d-table__cell">
                <input
                  class="dfp-settings-table__input"
                  placeholder={{i18n
                    "admin.adplugin.dfp_settings.gam_adunit_placeholder"
                  }}
                  value={{row.gam_adunit}}
                  {{on "input" (fn this.setField row "gam_adunit")}}
                />
              </td>
              <td class="d-table__cell">
                <input
                  class="dfp-settings-table__input"
                  placeholder={{i18n
                    "admin.adplugin.dfp_settings.gam_keywords_placeholder"
                  }}
                  value={{row.gam_keywords}}
                  {{on "input" (fn this.setField row "gam_keywords")}}
                />
              </td>
              <td class="d-table__cell">
                <input
                  class="dfp-settings-table__input"
                  placeholder={{i18n
                    "admin.adplugin.dfp_settings.gtm_taxonomy_placeholder"
                  }}
                  value={{row.gtm_taxonomy}}
                  {{on "input" (fn this.setField row "gtm_taxonomy")}}
                />
              </td>
              <td class="d-table__cell --controls">
                <DButton
                  @action={{fn this.save row}}
                  @icon="check"
                  @label="admin.adplugin.dfp_settings.save"
                />
                <DButton
                  @action={{fn this.destroy row}}
                  @danger={{true}}
                  @icon="trash-can"
                />
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>

      <DButton
        class="btn-default dfp-settings-table__add"
        @action={{this.addRow}}
        @icon="plus"
        @label="admin.adplugin.dfp_settings.add"
      />
    {{/if}}
  </template>
}
