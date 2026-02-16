import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";
import HouseAdsCategorySelector from "./house-ads-category-selector";
import HouseAdsRouteSelector from "./house-ads-route-selector";
import Preview from "./modal/preview";

export default class HouseAdForm extends Component {
  @service router;
  @service modal;
  @service dialog;
  @service toasts;
  @service siteSettings;
  @service site;

  get isNew() {
    return !this.args.model.id;
  }

  get routesEnabled() {
    return this.siteSettings.ad_plugin_routes_enabled;
  }

  get categoryDescription() {
    if (this.routesEnabled) {
      return i18n(
        "admin.adplugin.house_ads.category_chooser_description_with_routes"
      );
    }
    return i18n("admin.adplugin.house_ads.category_chooser_description");
  }

  get formData() {
    const model = this.args.model;
    return {
      id: model.id,
      name: model.name,
      html: model.html,
      visible_to_logged_in_users: model.visible_to_logged_in_users,
      visible_to_anons: model.visible_to_anons,
      categories: model.categories || [],
      group_ids: model.groups || [],
      routes: model.routes || [],
    };
  }

  @action
  async save(data) {
    const isNew = !data.id;
    const payload = {
      name: data.name,
      html: data.html,
      visible_to_logged_in_users: data.visible_to_logged_in_users,
      visible_to_anons: data.visible_to_anons,
      category_ids: data.categories ? data.categories.map((c) => c.id) : [],
      group_ids: data.group_ids || [],
      routes: data.routes || [],
    };

    try {
      const result = await ajax(
        isNew
          ? `/admin/plugins/pluginad/house_creatives`
          : `/admin/plugins/pluginad/house_creatives/${data.id}`,
        {
          type: isNew ? "POST" : "PUT",
          data: payload,
        }
      );

      this.toasts.success({
        data: { message: i18n("saved") },
        duration: "short",
      });

      const categories = data.categories ? [...data.categories] : [];
      const groups = data.group_ids ? [...data.group_ids] : [];
      const routes = data.routes ? [...data.routes] : [];

      const houseAds = this.args.houseAds;
      if (isNew) {
        const newAd = {
          id: result.house_ad.id,
          name: data.name,
          html: data.html,
          visible_to_logged_in_users: data.visible_to_logged_in_users,
          visible_to_anons: data.visible_to_anons,
          categories,
          groups,
          routes,
        };
        houseAds.push(newAd);
        this.router.transitionTo(
          "adminPlugins.show.houseAds.show",
          result.house_ad.id
        );
      } else {
        const updatedProps = {
          id: data.id,
          name: data.name,
          html: data.html,
          visible_to_logged_in_users: data.visible_to_logged_in_users,
          visible_to_anons: data.visible_to_anons,
          categories,
          groups,
          routes,
        };
        const existing = houseAds.find((ad) => ad.id === data.id);
        if (existing) {
          Object.assign(existing, updatedProps);
        }
        Object.assign(this.args.model, updatedProps);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  delete() {
    if (this.isNew) {
      this.router.transitionTo("adminPlugins.show.houseAds.index");
      return;
    }

    return this.dialog.confirm({
      message: i18n("admin.adplugin.house_ads.confirm_delete"),

      didConfirm: async () => {
        try {
          await ajax(
            `/admin/plugins/pluginad/house_creatives/${this.args.model.id}`,
            { type: "DELETE" }
          );
          removeValueFromArray(
            this.args.houseAds,
            this.args.houseAds.find((ad) => ad.id === this.args.model.id)
          );
          this.router.transitionTo("adminPlugins.show.houseAds.index");
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  openPreview(data) {
    this.modal.show(Preview, {
      model: { html: data.html },
    });
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="house-ad-form"
      as |form data|
    >
      <form.Field
        @name="name"
        @title={{i18n "admin.adplugin.house_ads.name"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="html"
        @title={{i18n "admin.adplugin.house_ads.html"}}
        @validation="required"
        @format="full"
        as |field|
      >
        <field.Code @lang="html" @height={{270}} />
      </form.Field>

      <form.Field
        @name="visible_to_logged_in_users"
        @title={{i18n "admin.adplugin.house_ads.show_to_logged_in_users"}}
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="visible_to_anons"
        @title={{i18n "admin.adplugin.house_ads.show_to_anons"}}
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Field
        @name="categories"
        @title={{i18n "admin.adplugin.house_ads.categories"}}
        @description={{this.categoryDescription}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <HouseAdsCategorySelector
            @categories={{this.site.categories}}
            @selectedCategories={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      {{#if this.routesEnabled}}
        <form.Field
          @name="routes"
          @title={{i18n "admin.adplugin.house_ads.routes"}}
          @description={{i18n
            "admin.adplugin.house_ads.route_chooser_description"
          }}
          @format="large"
          as |field|
        >
          <field.Custom>
            <HouseAdsRouteSelector
              @value={{field.value}}
              @onChange={{field.set}}
            />
          </field.Custom>
        </form.Field>
      {{/if}}

      <form.Field
        @name="group_ids"
        @title={{i18n "admin.adplugin.house_ads.groups"}}
        @description={{i18n
          "admin.adplugin.house_ads.group_chooser_description"
        }}
        @format="large"
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Actions>
        <form.Submit @label="admin.adplugin.house_ads.save" />
        <form.Button
          @action={{fn this.openPreview data}}
          @label="admin.adplugin.house_ads.preview"
        />
        {{#unless this.isNew}}
          <form.Button
            @action={{this.delete}}
            @label="admin.adplugin.house_ads.delete"
            class="btn-danger"
          />
        {{/unless}}
      </form.Actions>
    </Form>
  </template>
}
