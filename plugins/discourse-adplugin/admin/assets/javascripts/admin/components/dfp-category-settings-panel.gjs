import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

const PATH = "/admin/plugins/pluginad/dfp_category_settings";

export default class DfpCategorySettingsPanel extends Component {
  @service dialog;
  @service toasts;

  @action
  delete(setting) {
    this.dialog.deleteConfirm({
      message: i18n("admin.adplugin.dfp_settings.confirm_delete"),
      didConfirm: async () => {
        try {
          await ajax(`${PATH}/${setting.id}`, { type: "DELETE" });
          this.args.settings.splice(this.args.settings.indexOf(setting), 1);
          this.toasts.success({
            data: {
              message: i18n("admin.adplugin.dfp_settings.delete_success"),
            },
            duration: "short",
          });
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    {{#if @settings.length}}
      <table class="d-table dfp-category-settings">
        <thead class="d-table__header">
          <tr class="d-table__row">
            <th class="d-table__header-cell">
              {{i18n "admin.adplugin.dfp_settings.category"}}
            </th>
            <th class="d-table__header-cell">
              {{i18n "adplugin.gam_adunit"}}
            </th>
            <th class="d-table__header-cell">
              {{i18n "adplugin.gam_keywords"}}
            </th>
            <th class="d-table__header-cell">
              {{i18n "adplugin.gtm_taxonomy"}}
            </th>
            <th></th>
          </tr>
        </thead>
        <tbody class="d-table__body">
          {{#each @settings as |setting|}}
            <tr class="d-table__row dfp-category-settings__row">
              <td class="d-table__cell --overview">
                {{#if setting.category}}
                  {{dCategoryBadge setting.category}}
                {{else}}
                  {{i18n "admin.adplugin.dfp_settings.unknown_category"}}
                {{/if}}
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "adplugin.gam_adunit"}}
                </div>
                <span class="dfp-category-settings__value">
                  {{if
                    setting.gam_adunit
                    setting.gam_adunit
                    (i18n "admin.adplugin.dfp_settings.not_set")
                  }}
                </span>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "adplugin.gam_keywords"}}
                </div>
                <span class="dfp-category-settings__value">
                  {{if
                    setting.gam_keywords
                    setting.gam_keywords
                    (i18n "admin.adplugin.dfp_settings.not_set")
                  }}
                </span>
              </td>
              <td class="d-table__cell --detail">
                <div class="d-table__mobile-label">
                  {{i18n "adplugin.gtm_taxonomy"}}
                </div>
                <span class="dfp-category-settings__value">
                  {{if
                    setting.gtm_taxonomy
                    setting.gtm_taxonomy
                    (i18n "admin.adplugin.dfp_settings.not_set")
                  }}
                </span>
              </td>
              <td class="d-table__cell --controls">
                <div class="d-table__cell-actions">
                  <DButton
                    class="btn-default btn-small dfp-category-settings__edit"
                    @icon="pencil"
                    @route="adminPlugins.show.dfpSettings.edit"
                    @routeModels={{setting.id}}
                    @title="admin.adplugin.dfp_settings.edit"
                  />
                  <DButton
                    class="btn-danger btn-small dfp-category-settings__delete"
                    @action={{fn this.delete setting}}
                    @icon="trash-can"
                    @title="admin.adplugin.dfp_settings.delete"
                  />
                </div>
              </td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <AdminConfigAreaEmptyList
        @ctaLabel="admin.adplugin.dfp_settings.add"
        @ctaRoute="adminPlugins.show.dfpSettings.new"
        @emptyLabel="admin.adplugin.dfp_settings.empty"
      />
    {{/if}}
  </template>
}
