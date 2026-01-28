import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import EmojiPicker from "discourse/components/emoji-picker";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import categoryBadge from "discourse/helpers/category-badge";
import icon from "discourse/helpers/d-icon";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { AUTO_GROUPS, CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryGeneral extends Component {
  @service site;
  @service siteSettings;

  @tracked categoryVisibilityState = null;
  @tracked userModifiedPermissions = false;

  uncategorizedSiteSettingLink = getURL(
    "/admin/site_settings/category/all_results?filter=allow_uncategorized_topics"
  );
  customizeTextContentLink = getURL(
    "/admin/customize/site_texts?q=uncategorized"
  );

  get parentIsRestricted() {
    const parentId = this.args.transientData.parent_category_id;
    if (!parentId) {
      return false;
    }

    const parentCategory = Category.findById(parentId);
    if (!parentCategory?.permissions?.length) {
      return false;
    }

    const onlyEveryone =
      parentCategory.permissions.length === 1 &&
      (parentCategory.permissions[0].group_id === AUTO_GROUPS.everyone.id ||
        parentCategory.permissions[0].group_name === "everyone");

    return !onlyEveryone;
  }

  get isPrivateCategory() {
    const permissions = this.args.category.permissions;

    if (!permissions || permissions.length === 0) {
      return true;
    }

    const onlyEveryone =
      permissions.length === 1 &&
      (permissions[0].group_id === AUTO_GROUPS.everyone.id ||
        permissions[0].group_name === "everyone");

    return !onlyEveryone;
  }

  set isPrivateCategory(value) {
    if (value) {
      this.args.category.set("permissions", []);
    } else {
      const site = this.args.category.site;
      const everyoneGroup = site.groups.find(
        (g) => g.id === AUTO_GROUPS.everyone.id
      );

      this.args.category.set("permissions", [
        {
          group_name: everyoneGroup?.name || "everyone",
          group_id: AUTO_GROUPS.everyone.id,
          permission_type: PermissionType.FULL,
        },
      ]);
    }
  }

  get visibilityGroups() {
    const permissions = this.args.category.permissions || [];
    return permissions
      .filter((p) => p.permission_type <= PermissionType.READONLY)
      .map((p) => p.group_id);
  }

  get postingGroups() {
    const permissions = this.args.category.permissions || [];
    return permissions
      .filter((p) => p.permission_type <= PermissionType.CREATE_POST)
      .map((p) => p.group_id);
  }

  @action
  onChangeVisibilityGroups(groupIds) {
    const site = this.args.category.site;
    const currentPermissions = this.args.category.permissions || [];

    const postingGroupPermissions = new Map(
      currentPermissions
        .filter((p) => p.permission_type <= PermissionType.CREATE_POST)
        .map((p) => [p.group_id, p.permission_type])
    );

    const newPermissions = [];

    groupIds.forEach((groupId) => {
      const group = site.groups.find((g) => g.id === groupId);
      const existingPermission = postingGroupPermissions.get(groupId);

      newPermissions.push({
        group_name: group?.name,
        group_id: groupId,
        permission_type: existingPermission ?? PermissionType.READONLY,
      });
    });

    this.userModifiedPermissions = true;
    this.args.category.set("permissions", newPermissions);
  }

  @action
  onChangePostingGroups(groupIds) {
    // Posting groups automatically get visibility (if they can post, they can see)
    const site = this.args.category.site;
    const currentPermissions = this.args.category.permissions || [];
    const currentVisibilityGroupIds = currentPermissions.map((p) => p.group_id);
    const newPermissions = [];

    groupIds.forEach((groupId) => {
      const group = site.groups.find((g) => g.id === groupId);
      newPermissions.push({
        group_name: group?.name,
        group_id: groupId,
        permission_type: PermissionType.FULL,
      });
    });

    currentVisibilityGroupIds.forEach((groupId) => {
      if (!groupIds.includes(groupId)) {
        const group = site.groups.find((g) => g.id === groupId);
        newPermissions.push({
          group_name: group?.name,
          group_id: groupId,
          permission_type: PermissionType.READONLY,
        });
      }
    });

    this.userModifiedPermissions = true;
    this.args.category.set("permissions", newPermissions);
  }

  get allowSubCategoriesAsParent() {
    // If max_category_nesting is 2, only top-level categories can be parents
    // If max_category_nesting is 3, subcategories can also be parents
    return this.siteSettings.max_category_nesting > 2;
  }

  @cached
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

  @cached
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

    if (this.parentIsRestricted) {
      return "group_restricted";
    }

    return this.isPrivateCategory ? "group_restricted" : "public";
  }

  get publicVisibilityLabel() {
    return this.siteSettings.login_required
      ? "category.visibility.all_members"
      : "category.visibility.public";
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
  onVisibilityChange(value) {
    this.categoryVisibilityState = value;
    this.userModifiedPermissions = true;
    if (value === "public") {
      this.isPrivateCategory = false;
    } else if (value === "group_restricted") {
      this.isPrivateCategory = true;
    }
  }

  @action
  async onParentCategoryChange(parentCategoryId) {
    if (!parentCategoryId) {
      if (!this.userModifiedPermissions) {
        const site = this.args.category.site;
        const everyoneGroup = site.groups.find(
          (g) => g.id === AUTO_GROUPS.everyone.id
        );
        this.args.category.set("permissions", [
          {
            group_name: everyoneGroup?.name || "everyone",
            group_id: AUTO_GROUPS.everyone.id,
            permission_type: PermissionType.FULL,
          },
        ]);
      }
      return;
    }

    const result = await Category.reloadById(parentCategoryId);
    const site = this.args.category.site;
    const parentCategory = site.updateCategory(result.category);
    parentCategory.setupGroupsAndPermissions();

    if (parentCategory?.permissions?.length > 0) {
      const onlyEveryone =
        parentCategory.permissions.length === 1 &&
        (parentCategory.permissions[0].group_id === AUTO_GROUPS.everyone.id ||
          parentCategory.permissions[0].group_name === "everyone");

      if (!onlyEveryone) {
        const newPermissions = parentCategory.permissions.map((p) => ({
          group_name: p.group_name,
          group_id: p.group_id,
          permission_type: p.permission_type,
        }));

        this.args.category.set("permissions", newPermissions);
      } else {
        const everyoneGroup = site.groups.find(
          (g) => g.id === AUTO_GROUPS.everyone.id
        );

        this.args.category.set("permissions", [
          {
            group_name: everyoneGroup?.name || "everyone",
            group_id: AUTO_GROUPS.everyone.id,
            permission_type: PermissionType.FULL,
          },
        ]);
      }
    }
  }

  @action
  async onParentCategorySet(value, { set, name, index }) {
    await set(name, value, { index });
    await this.onParentCategoryChange(value);
  }

  @action
  togglePrivateCategory() {
    this.isPrivateCategory = !this.isPrivateCategory;
  }

  get showWarning() {
    return this.args.category.isUncategorizedCategory;
  }

  @cached
  get subCategories() {
    if (this.args.category.isNew) {
      return null;
    }
    return Category.list().filter(
      (category) => category.get("parent_category_id") === this.args.category.id
    );
  }

  @cached
  get showDescription() {
    const category = this.args.category;
    return (
      !category.isUncategorizedCategory && category.id && category.topic_url
    );
  }

  @action
  showCategoryTopic() {
    window.open(this.args.category.get("topic_url"), "_blank").focus();
  }

  @action
  async onBackgroundColorSet(value, { set }) {
    const color = value?.replace(/^#/, "") ?? "";

    await set("color", color);

    if (color) {
      const whiteDiff = this.colorDifference(color, CATEGORY_TEXT_COLORS[0]);
      const blackDiff = this.colorDifference(color, CATEGORY_TEXT_COLORS[1]);
      const colorIndex = whiteDiff > blackDiff ? 0 : 1;

      this.args.form.set("text_color", CATEGORY_TEXT_COLORS[colorIndex]);
    }
  }

  @action
  async onNameChange(value, { set, name, index }) {
    await set(name, value, { index });
  }

  @action
  async onIconSet(value, { set, name, index }) {
    await set(name, value, { index });
  }

  @action
  async onEmojiSet(value, { set, name, index }) {
    await set(name, value, { index });
  }

  @action
  onStyleTypeChange(value) {
    this.args.form.setProperties({ style_type: value });

    const updateData = { style_type: value };

    // Use transientData (current form values) if available, otherwise fall back to category model
    const currentIcon =
      this.args.transientData?.icon ?? this.args.category.icon ?? null;
    const currentEmoji =
      this.args.transientData?.emoji ?? this.args.category.emoji ?? null;

    if (value === "icon" && currentIcon) {
      updateData.icon = currentIcon;
    } else if (value === "emoji" && currentEmoji) {
      updateData.emoji = currentEmoji;
    }
  }

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
  validateColor(name, color, { addError }) {
    color = color.trim();

    let title;
    if (name === "color") {
      title = i18n("category.background_color");
    } else if (name === "text_color") {
      title = i18n("category.foreground_color");
    } else {
      throw new Error(`unknown title for category attribute ${name}`);
    }

    if (!color) {
      addError(name, {
        title,
        message: i18n("category.color_validations.cant_be_empty"),
      });
    }

    if (color.length !== 3 && color.length !== 6) {
      addError(name, {
        title,
        message: i18n("category.color_validations.incorrect_length"),
      });
    }

    if (!/^[0-9A-Fa-f]+$/.test(color)) {
      addError(name, {
        title,
        message: i18n("category.color_validations.non_hexdecimal"),
      });
    }
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

  get categoryDescription() {
    if (this.args.category.description) {
      return htmlSafe(this.args.category.description);
    }

    return htmlSafe(i18n("category.no_description"));
  }

  @action
  goToSecurityTab(event) {
    event.preventDefault();
    this.args.setSelectedTab?.("security");
  }

  get canSelectParentCategory() {
    return !this.args.category.isUncategorizedCategory;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "general" ? "active" : "";
    return `edit-category-tab edit-category-tab-general ${isActive}`;
  }

  <template>
    <div class={{this.panelClass}}>
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
          @onSet={{this.onNameChange}}
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

      <@form.Container @title={{i18n "category.style"}}>
        <@form.ConditionalContent
          @activeName={{or
            @transientData.style_type
            @category.styleType
            "square"
          }}
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
                @onSet={{this.onIconSet}}
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
                @onSet={{this.onEmojiSet}}
                @validate={{this.validateEmoji}}
                as |field|
              >
                <field.Custom>
                  <EmojiPicker
                    @emoji={{field.value}}
                    @didSelectEmoji={{field.set}}
                    @modalForMobile={{false}}
                    @btnClass="btn-default btn-emoji"
                    @label={{unless field.value (i18n "category.select_emoji")}}
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
      </@form.Container>

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
              }}
            />
          </field.Custom>
        </@form.Field>
      {{/unless}}

      <@form.Container
        @title={{i18n "category.visibility.title"}}
        class="--radio-cards"
      >
        <@form.ConditionalContent
          @activeName={{this.categoryVisibility}}
          @onChange={{this.onVisibilityChange}}
          as |cc|
        >
          <cc.Conditions as |Condition|>
            {{#if this.parentIsRestricted}}
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
                @title={{i18n "category.visibility.who_can_see"}}
              >
                <GroupChooser
                  @content={{@category.site.groups}}
                  @value={{this.visibilityGroups}}
                  @onChange={{this.onChangeVisibilityGroups}}
                />
              </@form.Container>

              <@form.Container
                @title={{i18n "category.visibility.who_can_post"}}
              >
                <GroupChooser
                  @content={{@category.site.groups}}
                  @value={{this.postingGroups}}
                  @onChange={{this.onChangePostingGroups}}
                />
              </@form.Container>

              <span class="category-permission-hint">
                {{i18n "category.visibility.more_options_hint"}}
                <a href {{on "click" this.goToSecurityTab}}>
                  {{i18n "category.visibility.more_options_hint_link"}}
                </a>
              </span>
            </Content>
          </cc.Contents>
        </@form.ConditionalContent>
      </@form.Container>

    </div>
  </template>
}
