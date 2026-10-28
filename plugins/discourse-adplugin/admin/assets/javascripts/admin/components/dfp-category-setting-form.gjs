import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import { i18n } from "discourse-i18n";

const PATH = "/admin/plugins/pluginad/dfp_category_settings";

export default class DfpCategorySettingForm extends Component {
  @service router;
  @service toasts;

  #formApi = null;

  @cached
  get formData() {
    const { setting } = this.args.model;

    return {
      category_id: setting.category_id,
      gam_adunit: setting.gam_adunit || "",
      gam_keywords: setting.gam_keywords || "",
      gtm_taxonomy: setting.gtm_taxonomy || "",
    };
  }

  get heading() {
    return this.args.model.setting.id
      ? "admin.adplugin.dfp_settings.edit_title"
      : "admin.adplugin.dfp_settings.new_title";
  }

  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  @action
  async save(data) {
    const { setting, settings } = this.args.model;
    const isNew = !setting.id;

    try {
      const result = await ajax(isNew ? PATH : `${PATH}/${setting.id}`, {
        type: isNew ? "POST" : "PUT",
        data,
      });
      const savedSetting = {
        ...result.dfp_category_setting,
        category: Category.findById(result.dfp_category_setting.category_id),
      };

      if (isNew) {
        settings.unshift(savedSetting);
      } else {
        settings.splice(settings.indexOf(setting), 1, savedSetting);
      }

      // commit after the request succeeds so the post-save transition is not
      // blocked by the dirty-form guard; a failed save leaves it dirty.
      this.#formApi?.commit();

      this.toasts.success({
        data: { message: i18n("admin.adplugin.dfp_settings.save_success") },
        duration: "short",
      });
      this.router.transitionTo("adminPlugins.show.dfpSettings.index");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content dfp-category-setting-form">
        <AdminConfigAreaCard @heading={{this.heading}}>
          <:content>
            <Form
              @commitOnSubmit={{false}}
              @data={{this.formData}}
              @onRegisterApi={{this.registerFormApi}}
              @onSubmit={{this.save}}
              as |form|
            >
              <form.Field
                @description={{i18n
                  "admin.adplugin.dfp_settings.category_description"
                }}
                @format="full"
                @name="category_id"
                @title={{i18n "admin.adplugin.dfp_settings.category"}}
                @type="custom"
                @validation="required"
                as |field|
              >
                <field.Control>
                  <CategoryChooser
                    @allowRestrictedCategories={{true}}
                    @onChange={{field.set}}
                    @options={{hash allowUncategorized=false}}
                    @value={{field.value}}
                  />
                </field.Control>
              </form.Field>

              <form.Field
                @description={{i18n
                  "admin.adplugin.dfp_settings.gam_adunit_description"
                }}
                @format="full"
                @name="gam_adunit"
                @title={{i18n "adplugin.gam_adunit"}}
                @type="input"
                as |field|
              >
                <field.Control
                  maxlength="255"
                  placeholder={{i18n "adplugin.gam_adunit_placeholder"}}
                />
              </form.Field>

              <form.Field
                @description={{i18n
                  "admin.adplugin.dfp_settings.gam_keywords_description"
                }}
                @format="full"
                @name="gam_keywords"
                @title={{i18n "adplugin.gam_keywords"}}
                @type="input"
                as |field|
              >
                <field.Control
                  maxlength="255"
                  placeholder={{i18n "adplugin.gam_keywords_placeholder"}}
                />
              </form.Field>

              <form.Field
                @description={{i18n
                  "admin.adplugin.dfp_settings.gtm_taxonomy_description"
                }}
                @format="full"
                @name="gtm_taxonomy"
                @title={{i18n "adplugin.gtm_taxonomy"}}
                @type="input"
                as |field|
              >
                <field.Control
                  maxlength="255"
                  placeholder={{i18n "adplugin.gtm_taxonomy_placeholder"}}
                />
              </form.Field>

              <form.Actions>
                <form.Submit
                  @icon="check"
                  @label="admin.adplugin.dfp_settings.save"
                />
              </form.Actions>
            </Form>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
