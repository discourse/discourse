import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import EmojiPicker from "discourse/components/emoji-picker";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import categoryBadge from "discourse/helpers/category-badge";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { AUTO_GROUPS, CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import { eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const EVERYONE_FULL_PERMISSION = {
  group_id: AUTO_GROUPS.everyone.id,
  group_name: AUTO_GROUPS.everyone.name,
  permission_type: PermissionType.FULL,
};

export default class UpsertCategoryGeneral extends Component {
  @service site;
  @service siteSettings;

  @tracked categoryVisibilityState = null;

  uncategorizedSiteSettingLink = getURL(
    "/admin/site_settings/category/all_results?filter=allow_uncategorized_topics"
  );

  customizeTextContentLink = getURL(
    "/admin/customize/site_texts?q=uncategorized"
  );

  #previousPermissions = null;

  get isParentRestricted() {
    const parentId = this.args.transientData.parent_category_id;
    if (!parentId) {
      return false;
    }

    const parentCategory = Category.findById(parentId);
    if (!parentCategory?.permissions?.length) {
      return false;
    }

    return !parentCategory.permissions.some(
      (p) => p.group_id === AUTO_GROUPS.everyone.id
    );
  }

  get permissions() {
    return (
      this.args.transientData?.permissions ?? this.args.category.permissions
    );
  }

  get isPrivateCategory() {
    if (!this.permissions || this.permissions.length === 0) {
      return true;
    }

    return !this.permissions.some(
      (p) => p.group_id === AUTO_GROUPS.everyone.id
    );
  }

  get accessGroups() {
    return (this.permissions || []).map((p) => p.group_id);
  }

  get availableAccessGroups() {
    const groups = this.site.groups.filter(
      (g) => g.id !== AUTO_GROUPS.everyone.id
    );

    if (!this.isParentRestricted) {
      return groups;
    }

    const parentId = this.args.transientData.parent_category_id;
    const parentCategory = Category.findById(parentId);
    const parentGroupIds = new Set(
      parentCategory.permissions.map((p) => p.group_id)
    );

    return groups.filter((g) => parentGroupIds.has(g.id));
  }

  @action
  onChangeAccessGroups(groupIds) {
    const newPermissions = groupIds.map((groupId) => {
      const group = this.site.groups.find((g) => g.id === groupId);
      return {
        group_id: groupId,
        group_name: group?.name,
        permission_type: PermissionType.FULL,
      };
    });

    this.#setFormPermissions(newPermissions);
  }

  get allowSubCategoriesAsParent() {
    // If max_category_nesting is 2, only top-level categories can be parents
    // If max_category_nesting is 3, subcategories can also be parents
    return this.siteSettings.max_category_nesting > 2;
  }

  get backgroundColors() {
    const categories = this.site.get("categoriesList");
    return uniqueItemsFromArray(
      this.siteSettings.category_colors
        .split("|")
        .filter(Boolean)
        .map((i) => i.toUpperCase())
        .concat(categories.map((c) => c.color.toUpperCase()))
    );
  }

  get usedBackgroundColors() {
    const categories = this.site.get("categoriesList");
    const categoryId = this.args.category.id;
    const categoryColor = this.args.category.color;

    return categories
      .map((c) => {
        return categoryId &&
          categoryColor?.toUpperCase() === c.color.toUpperCase()
          ? null
          : c.color.toUpperCase();
      })
      .filter((item) => item != null);
  }

  get categoryVisibility() {
    if (this.categoryVisibilityState) {
      return this.categoryVisibilityState;
    }

    if (this.isParentRestricted) {
      return "group_restricted";
    }

    return this.isPrivateCategory ? "group_restricted" : "public";
  }

  get publicVisibilityLabel() {
    return this.siteSettings.login_required
      ? "category.visibility.all_members"
      : "category.visibility.public";
  }

  get showWarning() {
    return this.args.category.isUncategorizedCategory;
  }

  get permissionHint() {
    const key = this.isParentRestricted
      ? "category.visibility.inherited_from_parent"
      : "category.visibility.more_options_hint";
    return htmlSafe(i18n(key));
  }

  @action
  buildTransientModel(transientData) {
    return Category.create({
      id: transientData.id,
      name: transientData.name || i18n("category.untitled"),
      color: transientData.color,
      text_color: transientData.text_color,
      parent_category_id: transientData.parent_category_id,
    });
  }

  @action
  onChangeVisibility(value) {
    // Save current permissions before switching to public
    if (value === "public" && this.isPrivateCategory) {
      this.#previousPermissions = (this.permissions || []).map((p) => ({
        ...p,
      }));
    }

    this.categoryVisibilityState = value;

    if (value === "public") {
      this.#setFormPermissions([EVERYONE_FULL_PERMISSION]);
    } else if (value === "group_restricted") {
      if (this.#previousPermissions?.length) {
        this.#setFormPermissions(this.#previousPermissions);
      } else {
        this.#setFormPermissions([]);
      }
    }
  }

  @action
  async onParentCategoryChange(parentCategoryId) {
    if (!parentCategoryId) {
      this.categoryVisibilityState = null;
      this.#setFormPermissions([EVERYONE_FULL_PERMISSION]);
      return;
    }

    try {
      const result = await Category.reloadById(parentCategoryId);
      const parentCategory = this.site.updateCategory(result.category);
      parentCategory.setupGroupsAndPermissions();

      if (parentCategory?.permissions?.length > 0) {
        const hasEveryone = parentCategory.permissions.some(
          (p) => p.group_id === AUTO_GROUPS.everyone.id
        );

        if (!hasEveryone) {
          this.categoryVisibilityState = null;

          const newPermissions = parentCategory.permissions.map((p) => ({
            group_name: p.group_name,
            group_id: p.group_id,
            permission_type: p.permission_type,
          }));

          this.#setFormPermissions(newPermissions);
        } else {
          this.#setFormPermissions([EVERYONE_FULL_PERMISSION]);
        }
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async onParentCategorySet(value, { set, name, index }) {
    await set(name, value, { index });
    await this.onParentCategoryChange(value);
  }

  @action
  async onBackgroundColorSet(value, { set }) {
    const color = value?.replace(/^#/, "") ?? "";

    await set("color", color);

    if (color) {
      const whiteDiff = this.#colorDifference(color, CATEGORY_TEXT_COLORS[0]);
      const blackDiff = this.#colorDifference(color, CATEGORY_TEXT_COLORS[1]);
      const colorIndex = whiteDiff > blackDiff ? 0 : 1;

      this.args.form.set("text_color", CATEGORY_TEXT_COLORS[colorIndex]);
    }
  }

  @action
  onStyleTypeChange(value) {
    this.args.form.setProperties({ style_type: value });
  }

  @action
  validateEmoji(name, value, { addError, data }) {
    if (data.style_type === "emoji" && !value) {
      addError(name, {
        title: i18n("category.emoji"),
        message: i18n("category.validations.emoji_required"),
      });
    }
  }

  @action
  goToSecurityTab(event) {
    if (event.target.tagName === "A") {
      event.preventDefault();
      this.args.setSelectedTab?.("security");
    }
  }

  #colorDifference(color1, color2) {
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

  #setFormPermissions(permissions) {
    this.args.form.set("permissions", permissions);
  }

  <template>
    <div
      class={{concatClass
        "yolo"
        "edit-category-tab"
        "edit-category-tab-general"
        (if (eq @selectedTab "general") "active")
      }}
    >
      {{#if this.showWarning}}
        <@form.Alert @type="warning" @icon="triangle-exclamation">
          {{htmlSafe
            (i18n
              "category.uncategorized_general_warning"
              settingLink=this.uncategorizedSiteSettingLink
              customizeLink=this.customizeTextContentLink
            )
          }}
        </@form.Alert>
      {{/if}}

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
            data-1p-ignore
          />
        </@form.Field>
      {{/unless}}

      <@form.Field
        @name="color"
        @title={{i18n "category.background_color"}}
        @format="large"
        @validation="required"
        @onSet={{this.onBackgroundColorSet}}
        as |field|
      >
        <field.Color
          @colors={{this.backgroundColors}}
          @usedColors={{this.usedBackgroundColors}}
          @collapseSwatches={{true}}
          @collapseSwatchesLabel={{i18n "category.color_palette"}}
          @fallbackValue={{@category.color}}
        />
      </@form.Field>

      <@form.Field
        @name="style_type"
        @title={{i18n "category.style"}}
        @format="large"
        as |styleField|
      >
        <styleField.Custom>
          <@form.ConditionalContent
            @activeName={{or styleField.value @category.styleType "square"}}
            @onChange={{this.onStyleTypeChange}}
            as |cc|
          >
            <cc.Conditions as |Condition|>
              <Condition @name="icon">
                {{i18n "category.styles.icon"}}
              </Condition>
              <Condition @name="emoji">
                {{i18n "category.styles.emoji"}}
              </Condition>
              <Condition @name="square">
                {{i18n "category.styles.square"}}
              </Condition>
            </cc.Conditions>

            <cc.Contents as |Content|>
              <Content @name="icon">
                <@form.Field
                  @name="icon"
                  @title={{i18n "category.icon"}}
                  @showTitle={{false}}
                  @format="large"
                  as |field|
                >
                  <field.Custom>
                    <IconPicker
                      @value={{readonly field.value}}
                      @onlyAvailable={{true}}
                      @options={{hash
                        maximum=1
                        disabled=field.disabled
                        caretDownIcon="angle-down"
                        caretUpIcon="angle-up"
                        icons=field.value
                      }}
                      @onChange={{field.set}}
                      class="form-kit__control-icon"
                      style={{htmlSafe
                        (concat "--icon-color: #" @transientData.color ";")
                      }}
                    />
                  </field.Custom>
                </@form.Field>
              </Content>

              <Content @name="emoji">
                <@form.Field
                  @name="emoji"
                  @title={{i18n "category.emoji"}}
                  @showTitle={{false}}
                  @format="large"
                  @validate={{this.validateEmoji}}
                  as |field|
                >
                  <field.Custom>
                    <EmojiPicker
                      @emoji={{field.value}}
                      @didSelectEmoji={{field.set}}
                      @modalForMobile={{false}}
                      @btnClass="btn-default btn-emoji"
                      @label={{unless
                        field.value
                        (i18n "category.select_emoji")
                      }}
                    />
                  </field.Custom>
                </@form.Field>
              </Content>

              <Content @name="square">
                {{htmlSafe
                  (categoryBadge
                    (this.buildTransientModel @transientData) styleType="square"
                  )
                }}
              </Content>
            </cc.Contents>
          </@form.ConditionalContent>
        </styleField.Custom>
      </@form.Field>

      {{#unless @category.isUncategorizedCategory}}
        <@form.Field
          @name="parent_category_id"
          @title={{i18n "category.subcategory_of"}}
          @format="large"
          @onSet={{this.onParentCategorySet}}
          as |field|
        >
          <field.Custom>
            <CategoryChooser
              @value={{@transientData.parent_category_id}}
              @onChange={{field.set}}
              @options={{hash
                allowSubCategories=this.allowSubCategoriesAsParent
                allowRestrictedCategories=true
                allowUncategorized=false
                excludeCategoryId=@category.id
                none="category.none_subcategory_text"
                clearable=true
                caretUpIcon="chevron-up"
                caretDownIcon="chevron-down"
                displayCategoryDescription=false
              }}
            />
          </field.Custom>
        </@form.Field>
      {{/unless}}

      <@form.Container
        @title={{i18n "category.visibility.title"}}
        class="--radio-cards"
        @format="large"
      >
        <@form.ConditionalContent
          @activeName={{this.categoryVisibility}}
          @onChange={{this.onChangeVisibility}}
          as |cc|
        >
          <cc.Conditions as |Condition|>
            {{#if this.isParentRestricted}}
              <DTooltip
                @content={{i18n "category.subcategory_permissions_warning"}}
              >
                <:trigger>
                  <Condition @name="public" @disabled={{true}}>
                    {{icon "ban"}}
                    {{i18n this.publicVisibilityLabel}}
                  </Condition>
                </:trigger>
              </DTooltip>
            {{else}}
              <Condition @name="public">
                {{icon "check"}}
                {{i18n this.publicVisibilityLabel}}
              </Condition>
            {{/if}}
            <Condition @name="group_restricted">
              {{icon "check"}}
              {{i18n "category.visibility.group_restricted"}}
            </Condition>
          </cc.Conditions>

          <cc.Contents as |Content|>
            <Content @name="group_restricted">
              <@form.Container
                @title={{i18n "category.visibility.which_groups_can_access"}}
                @format="large"
              >
                <GroupChooser
                  @content={{this.availableAccessGroups}}
                  @value={{this.accessGroups}}
                  @onChange={{this.onChangeAccessGroups}}
                  @options={{hash disabled=this.isParentRestricted}}
                />
              </@form.Container>

              {{! template-lint-disable no-invalid-interactive }}
              <span
                class="category-permission-hint"
                {{on "click" this.goToSecurityTab}}
              >
                {{this.permissionHint}}
              </span>
            </Content>
          </cc.Contents>
        </@form.ConditionalContent>
      </@form.Container>

    </div>
  </template>
}
