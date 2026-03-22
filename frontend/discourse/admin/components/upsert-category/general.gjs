import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DecoratedHtml from "discourse/components/decorated-html";
import EmojiPicker from "discourse/components/emoji-picker";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import categoryBadge from "discourse/helpers/category-badge";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { AUTO_GROUPS, CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import PermissionType from "discourse/models/permission-type";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import { eq, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryGeneral extends Component {
  @service appEvents;
  @service site;
  @service siteSettings;
  @service toasts;
  @service composer;
  @service store;

  @tracked loadingDescription = false;
  @tracked descriptionHtml = null;
  @tracked descriptionExpanded = false;
  @tracked descriptionOverflows = false;

  uncategorizedSiteSettingLink = getURL(
    "/admin/site_settings/category/all_results?filter=allow_uncategorized_topics"
  );

  customizeTextContentLink = getURL(
    "/admin/customize/site_texts?q=uncategorized"
  );

  #previousPermissions = null;

  @action
  registerDescriptionListener() {
    this.appEvents.on("composer:edited-post", this, this._refreshDescription);
  }

  @action
  unregisterDescriptionListener() {
    this.appEvents.off("composer:edited-post", this, this._refreshDescription);
  }

  @action
  checkDescriptionOverflow(element) {
    if (!this.descriptionExpanded) {
      this.descriptionOverflows = element.scrollHeight > element.clientHeight;
    }
  }

  @action
  toggleDescriptionExpanded() {
    this.descriptionExpanded = !this.descriptionExpanded;
  }

  async _refreshDescription() {
    const category = this.args.category;
    if (!category?.id) {
      return;
    }

    const result = await Category.reloadById(category.id);
    if (result?.category?.description) {
      category.set("description", result.category.description);
      this.descriptionHtml = result.category.description;

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("category.description_updated"),
        },
      });
    }
  }

  get showDescription() {
    const category = this.args.category;
    return (
      !category.isUncategorizedCategory && category.id && category.topic_url
    );
  }

  get categoryDescription() {
    const description = this.descriptionHtml ?? this.args.category.description;
    if (description) {
      return trustHTML(description);
    }

    return trustHTML(i18n("category.no_description"));
  }

  @action
  async editCategoryDescription() {
    this.loadingDescription = true;

    try {
      const topicData = await ajax(`${this.args.category.topic_url}.json`);
      const firstPost = topicData.post_stream?.posts?.[0];
      if (!firstPost) {
        return;
      }

      this.composer.close();

      const post = this.store.createRecord("post", firstPost);
      const topic = this.store.createRecord("topic", topicData);
      post.set("topic", topic);

      await this.composer.open({
        post,
        topic,
        action: Composer.EDIT,
        draftKey: topicData.draft_key || `topic_${topicData.id}`,
        draftSequence: topicData.draft_sequence ?? 0,
        skipJumpOnSave: true,
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingDescription = false;
    }
  }

  // This needs to be dynamic because the name of the everyone group can be changed by admins
  get #everyoneFullPermission() {
    return {
      group_id: AUTO_GROUPS.everyone.id,
      group_name: this.site.groupsById[AUTO_GROUPS.everyone.id].name,
      permission_type: PermissionType.FULL,
    };
  }

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
    if (!parentCategory?.permissions) {
      return groups;
    }

    const parentGroupIds = new Set(
      parentCategory.permissions.map((p) => p.group_id)
    );

    return groups.filter((g) => parentGroupIds.has(g.id));
  }

  @action
  onChangeAccessGroups(groupIds) {
    const existingPermissions = this.permissions || [];

    const newPermissions = groupIds.map((groupId) => {
      const existingPermission = existingPermissions.find(
        (p) => p.group_id === groupId
      );

      if (existingPermission) {
        return existingPermission;
      }

      return {
        group_id: groupId,
        group_name: this.site.groupsById[groupId]?.name,
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
    const visibility = this.args.transientData?.visibility;
    if (visibility) {
      return visibility;
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
    return trustHTML(i18n(key));
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

    this.args.form.set("visibility", value);

    if (value === "public") {
      this.#setFormPermissions([this.#everyoneFullPermission]);
    } else if (value === "group_restricted") {
      if (this.#previousPermissions?.length) {
        this.#setFormPermissions(this.#previousPermissions);
        this.#previousPermissions = null;
      } else {
        this.#setFormPermissions([]);
      }
    }
  }

  get #currentPermissionsArePrivate() {
    const currentPermissions = this.permissions || [];
    return (
      currentPermissions.length > 0 &&
      !currentPermissions.some((p) => p.group_id === AUTO_GROUPS.everyone.id)
    );
  }

  @action
  async onParentCategoryChange(parentCategoryId) {
    if (!parentCategoryId) {
      this.args.form.set("visibility", null);
      if (this.args.category.id) {
        return;
      }
      this.#setFormPermissions([this.#everyoneFullPermission]);
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
          this.args.form.set("visibility", null);

          // When editing an existing category, retain its permissions if they are more restrictive than the parent.
          // If the sub has groups the parent doesn't allow we must adopt parent's permissions.
          if (this.args.category.id && this.#currentPermissionsArePrivate) {
            const currentPermissions = this.permissions || [];
            const parentGroupIds = new Set(
              parentCategory.permissions.map((p) => p.group_id)
            );
            const subIsSubset = currentPermissions.every((p) =>
              parentGroupIds.has(p.group_id)
            );

            if (subIsSubset) {
              return;
            }
          }

          const newPermissions = parentCategory.permissions.map((p) => ({
            group_name: p.group_name,
            group_id: p.group_id,
            permission_type: p.permission_type,
          }));

          this.#setFormPermissions(newPermissions);
        } else {
          if (this.args.category.id) {
            return;
          }
          this.#setFormPermissions([this.#everyoneFullPermission]);
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
    this.args.form.set("style_type", value);
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
  validateIcon(name, value, { addError, data }) {
    if (data.style_type === "icon" && !value) {
      addError(name, {
        title: i18n("category.icon"),
        message: i18n("category.validations.icon_required"),
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
    <@form.Section
      class={{concatClass
        "edit-category-tab"
        "edit-category-tab-general"
        (if (eq @selectedTab "general") "active")
      }}
    >
      {{#if this.showWarning}}
        <@form.Alert @type="warning" @icon="triangle-exclamation">
          {{trustHTML
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
          @format="max"
          @validation="required"
          @type="input"
          as |field|
        >
          <field.Control
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
        @format="max"
        @validation="required"
        @onSet={{this.onBackgroundColorSet}}
        @type="color"
        as |field|
      >
        <field.Control
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
        @format="max"
        @type="custom"
        as |styleField|
      >
        <styleField.Control>
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
                  @format="max"
                  @validate={{this.validateIcon}}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
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
                      style={{trustHTML
                        (concat "--icon-color: #" @transientData.color ";")
                      }}
                    />
                  </field.Control>
                </@form.Field>
              </Content>

              <Content @name="emoji">
                <@form.Field
                  @name="emoji"
                  @title={{i18n "category.emoji"}}
                  @showTitle={{false}}
                  @format="max"
                  @validate={{this.validateEmoji}}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
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
                  </field.Control>
                </@form.Field>
              </Content>

              <Content @name="square">
                {{trustHTML
                  (categoryBadge
                    (this.buildTransientModel @transientData) styleType="square"
                  )
                }}
              </Content>
            </cc.Contents>
          </@form.ConditionalContent>
        </styleField.Control>
      </@form.Field>

      {{#if this.showDescription}}
        <div
          {{didInsert this.registerDescriptionListener}}
          {{willDestroy this.unregisterDescriptionListener}}
        >
          <@form.Container
            @title={{i18n "category.description"}}
            class="edit-category-description-container"
          >
            <div
              class={{concatClass
                "description-content"
                (unless this.descriptionExpanded "--collapsed")
                (if this.descriptionOverflows "--overflowing")
              }}
              {{didInsert this.checkDescriptionOverflow}}
              {{didUpdate
                this.checkDescriptionOverflow
                this.categoryDescription
              }}
            >
              <DecoratedHtml
                @html={{this.categoryDescription}}
                @className="readonly-field"
              />
            </div>

            <div class="description-actions">
              {{#if @category.topic_url}}
                <@form.Button
                  @action={{this.editCategoryDescription}}
                  @icon="pencil"
                  @label="edit"
                  @isLoading={{this.loadingDescription}}
                  class="btn-default btn-small edit-category-description"
                />
              {{/if}}
              {{#if this.descriptionOverflows}}
                <@form.Button
                  @action={{this.toggleDescriptionExpanded}}
                  @label={{if
                    this.descriptionExpanded
                    "category.description_collapse"
                    "category.description_expand"
                  }}
                  @icon={{if
                    this.descriptionExpanded
                    "chevron-up"
                    "chevron-down"
                  }}
                  class="btn-flat btn-small toggle-description"
                />
              {{/if}}
            </div>
          </@form.Container>
        </div>
      {{/if}}

      {{#unless @category.isUncategorizedCategory}}
        <@form.Field
          @name="parent_category_id"
          @title={{i18n "category.subcategory_of"}}
          @format="max"
          @onSet={{this.onParentCategorySet}}
          @type="custom"
          as |field|
        >
          <field.Control>
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
          </field.Control>
        </@form.Field>
      {{/unless}}

      <@form.Container
        @title={{i18n "category.visibility.title"}}
        class="--radio-cards"
        @format="max"
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
                @format="max"
              >
                <GroupChooser
                  @content={{this.availableAccessGroups}}
                  @value={{this.accessGroups}}
                  @onChange={{this.onChangeAccessGroups}}
                  @options={{hash disabled=this.isParentRestricted}}
                />
                {{! template-lint-disable no-invalid-interactive }}
                <span
                  class="category-permission-hint"
                  {{on "click" this.goToSecurityTab}}
                >
                  {{this.permissionHint}}
                </span>
              </@form.Container>
            </Content>
          </cc.Contents>
        </@form.ConditionalContent>
      </@form.Container>
    </@form.Section>
  </template>
}
