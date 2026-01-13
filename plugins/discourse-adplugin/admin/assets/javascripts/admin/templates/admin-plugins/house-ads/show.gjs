import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import AceEditor from "discourse/components/ace-editor";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";
import HouseAdsCategorySelector from "../../../components/house-ads-category-selector";
import HouseAdsRouteSelector from "../../../components/house-ads-route-selector";

export default <template>
  <section class="edit-house-ad content-body">
    <h1><TextField
        @value={{@controller.buffered.name}}
        class="house-ad-name"
      /></h1>
    <div class="controls">
      <AceEditor
        @content={{@controller.buffered.html}}
        @onChange={{fn (mut @controller.buffered.html)}}
        @mode="html"
      />
    </div>
    <div class="controls">
      <div class="visibility-settings">
        <div>
          <Input
            @type="checkbox"
            @checked={{@controller.buffered.visible_to_logged_in_users}}
            class="visible-to-logged-in-checkbox"
          />
          <span>{{i18n
              "admin.adplugin.house_ads.show_to_logged_in_users"
            }}</span>
        </div>

        <div>
          <Input
            class="visible-to-anonymous-checkbox"
            @type="checkbox"
            @checked={{@controller.buffered.visible_to_anons}}
          />
          <span>{{i18n "admin.adplugin.house_ads.show_to_anons"}}</span>
        </div>

        <HouseAdsCategorySelector
          @categories={{@controller.site.categories}}
          @selectedCategories={{@controller.selectedCategories}}
          @onChange={{@controller.setCategoryIds}}
          @options={{hash allowAny=true}}
          class="house-ads-categories"
        />
        <div class="description">
          {{#if @controller.routesEnabled}}
            {{i18n
              "admin.adplugin.house_ads.category_chooser_description_with_routes"
            }}
          {{else}}
            {{i18n "admin.adplugin.house_ads.category_chooser_description"}}
          {{/if}}
        </div>

        {{#if @controller.routesEnabled}}
          <HouseAdsRouteSelector
            @value={{@controller.selectedRoutes}}
            @onChange={{@controller.setRoutes}}
          />
          <div class="description">
            {{i18n "admin.adplugin.house_ads.route_chooser_description"}}
          </div>
        {{/if}}

        <GroupChooser
          @content={{@controller.site.groups}}
          @value={{@controller.selectedGroups}}
          @onChange={{@controller.setGroupIds}}
          class="banner-groups"
        />
        <div class="description">
          {{i18n "admin.adplugin.house_ads.group_chooser_description"}}
        </div>
      </div>

      <DButton
        @action={{@controller.save}}
        @disabled={{@controller.disabledSave}}
        @label="admin.adplugin.house_ads.save"
        class="btn-primary save-button"
      />

      {{#if @controller.saving}}
        {{@controller.savingStatus}}
      {{else}}
        {{#unless @controller.disabledSave}}
          <DButton @action={{@controller.cancel}} @label="cancel" />
        {{/unless}}
      {{/if}}

      <DButton
        @action={{@controller.openPreview}}
        @label="admin.adplugin.house_ads.preview"
      />

      <DButton
        @action={{@controller.destroy}}
        @label="admin.adplugin.house_ads.delete"
        class="btn-danger delete-button"
      />
    </div>
  </section>
</template>
