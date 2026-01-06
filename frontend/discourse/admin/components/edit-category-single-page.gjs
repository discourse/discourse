import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import ColorInput from "discourse/admin/components/color-input";
import ColorPicker from "discourse/components/color-picker";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import PermissionType from "discourse/models/permission-type";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

export default class EditCategorySinglePage extends Component {
  @tracked isPrivateCategory = false;

  get visibilityGroups() {
    // Groups that can see the category (read-only or higher)
    return this.args.category.permissions
      ?.filter((p) => p.permission_type >= PermissionType.READONLY)
      .map((p) => p.group_name);
  }

  get postingGroups() {
    // Groups that can post (create/reply or full)
    return this.args.category.permissions
      ?.filter((p) => p.permission_type >= PermissionType.CREATE_POST)
      .map((p) => p.group_name);
  }

  @action
  onChangeVisibilityGroups(groupNames) {
    // Set permissions: groups in this list get "see" permission (readonly)
    // Groups NOT in this list lose all permissions
    const site = this.args.category.site;
    const newPermissions = groupNames.map((groupName) => {
      const group = site.groups.find((g) => g.name === groupName);
      return {
        group_name: groupName,
        group_id: group?.id,
        permission_type: PermissionType.READONLY,
      };
    });
    this.args.category.set("permissions", newPermissions);
  }

  @action
  onChangePostingGroups(groupNames) {
    // Set permissions: groups in this list get "create/reply" permission
    const site = this.args.category.site;
    const currentPermissions = this.args.category.permissions || [];

    // Update or add posting groups
    const updatedPermissions = currentPermissions.map((p) => {
      if (groupNames.includes(p.group_name)) {
        return { ...p, permission_type: PermissionType.CREATE_POST };
      }
      return p;
    });

    // Add new groups that weren't in current permissions
    groupNames.forEach((groupName) => {
      if (!updatedPermissions.find((p) => p.group_name === groupName)) {
        const group = site.groups.find((g) => g.name === groupName);
        updatedPermissions.push({
          group_name: groupName,
          group_id: group?.id,
          permission_type: PermissionType.CREATE_POST,
        });
      }
    });

    this.args.category.set("permissions", updatedPermissions);
  }

  @action
  updateColor(field, newColor) {
    const color = newColor.replace("#", "");

    if (color === field.value) {
      return;
    }

    if (field.name === "color") {
      const whiteDiff = this.colorDifference(color, CATEGORY_TEXT_COLORS[0]);
      const blackDiff = this.colorDifference(color, CATEGORY_TEXT_COLORS[1]);
      const colorIndex = whiteDiff > blackDiff ? 0 : 1;

      this.args.form.setProperties({
        color,
        text_color: CATEGORY_TEXT_COLORS[colorIndex],
      });
    } else {
      field.set(color);
    }
  }

  @action
  colorDifference(color1, color2) {
    const r1 = parseInt(color1.substr(0, 2), 16);
    const g1 = parseInt(color1.substr(2, 2), 16);
    const b1 = parseInt(color1.substr(4, 2), 16);

    const r2 = parseInt(color2.substr(0, 2), 16);
    const g2 = parseInt(color2.substr(2, 2), 16);
    const b2 = parseInt(color2.substr(4, 2), 16);

    const rDiff = Math.max(r1, r2) - Math.min(r1, r2);
    const gDiff = Math.max(g1, g2) - Math.min(g1, g2);
    const bDiff = Math.max(b1, b2) - Math.min(b1, b2);

    return rDiff + gDiff + bDiff;
  }

  @action
  togglePrivateCategory() {
    this.isPrivateCategory = !this.isPrivateCategory;
  }

  <template>
    <div class="edit-category-single-page">
      {{#unless @category.isUncategorizedCategory}}
        <@form.Field
          @name="name"
          @title={{i18n "category.name"}}
          @format="large"
          @validation="required"
          as |field|
        >
          <field.Input
            placeholder={{i18n "category.name_placeholder"}}
            @maxlength="50"
            class="category-name"
          />
        </@form.Field>
      {{/unless}}

      {{#unless @category.isUncategorizedCategory}}
        <@form.Field
          @name="parent_category_id"
          @title={{i18n "category.parent"}}
          @format="large"
          class="parent-category"
          as |field|
        >
          <field.Custom>
            <CategoryChooser
              @value={{@transientData.parent_category_id}}
              @allowSubCategories={{true}}
              @allowRestrictedCategories={{true}}
              @onChange={{field.set}}
              @options={{hash
                allowUncategorized=false
                excludeCategoryId=@category.id
                autoInsertNoneItem=true
                none=true
              }}
            />
          </field.Custom>
        </@form.Field>
      {{/unless}}

      <@form.Field
        @name="icon"
        @title={{i18n "category.styles.icon"}}
        @format="large"
        @validation="required"
        as |field|
      >
        <field.Icon />
      </@form.Field>

      <@form.Field
        @name="color"
        @title={{i18n "category.background_color"}}
        @format="large"
        @validation="required"
        as |field|
      >
        <field.Custom>
          <div class="category-color-editor">
            <div class="colorpicker-wrapper edit-background-color">
              <ColorInput
                @hexValue={{readonly field.value}}
                @ariaLabelledby="background-color-label"
                @onChangeColor={{fn this.updateColor field}}
                @skipNormalize={{true}}
              />
              <ColorPicker
                @value={{readonly field.value}}
                @ariaLabel={{i18n "category.predefined_colors"}}
                @onSelectColor={{fn this.updateColor field}}
              />
            </div>
          </div>
        </field.Custom>
      </@form.Field>

      <@form.Container @title="Private category">
        <DToggleSwitch
          @state={{this.isPrivateCategory}}
          {{on "click" this.togglePrivateCategory}}
        />
      </@form.Container>

      {{#if this.isPrivateCategory}}
        <@form.Container @title="Who can see this category">
          <GroupChooser
            @content={{@category.site.groups}}
            @value={{this.visibilityGroups}}
            @onChange={{this.onChangeVisibilityGroups}}
          />
        </@form.Container>

        <@form.Container @title="Who can post in this category">
          <GroupChooser
            @content={{@category.site.groups}}
            @value={{this.postingGroups}}
            @onChange={{this.onChangePostingGroups}}
          />
        </@form.Container>
      {{/if}}
    </div>
  </template>
}
