import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import CategoryNameStyle from "discourse/admin/components/upsert-category/name-style";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  availableCategoryType,
  unavailableBadgeText,
} from "discourse/lib/category-type-utils";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { runOnBeforeCategoryTypesChange } from "discourse/lib/on-before-category-types-change";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import PermissionType from "discourse/models/permission-type";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DISCUSSION_TYPE_ID = "discussion";

export default class UpsertCategoryGeneral extends Component {
  @service appEvents;
  @service site;
  @service siteSettings;
  @service toasts;
  @service composer;
  @service store;
  @service categoryTypeChooser;

  @tracked loadingDescription = false;

  /** @type {string | null} */
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

  constructor() {
    super(...arguments);

    this.categoryTypes = [...this.categoryTypeChooser.allTypes].map((type) => ({
      ...type,
      preventRemoval: type.id === DISCUSSION_TYPE_ID,
    }));
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

  get allowSubCategoriesAsParent() {
    // If max_category_nesting is 2, only top-level categories can be parents
    // If max_category_nesting is 3, subcategories can also be parents
    return this.siteSettings.max_category_nesting > 2;
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

  get privateVisibilityLocked() {
    return applyValueTransformer("category-visibility-private-locked", false, {
      category: this.args.category,
      form: this.args.form,
      transientData: this.args.transientData,
    });
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

  get #currentPermissionsArePrivate() {
    const currentPermissions = this.permissions || [];
    return (
      currentPermissions.length > 0 &&
      !currentPermissions.some((p) => p.group_id === AUTO_GROUPS.everyone.id)
    );
  }

  get isEditingExistingCategory() {
    return this.args.category.id != null;
  }

  @bind
  mapCategoryTypeIdsToTypes(ids) {
    if (!ids?.length) {
      return [];
    }

    return ids
      .map((id) => this.categoryTypes.find((type) => type.id === id))
      .filter(Boolean);
  }

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

  @action
  onChangeVisibility(value) {
    // Wrapped so consumers can intercept the change; skipping `next` vetoes it.
    return applyBehaviorTransformer(
      "category-visibility-change",
      () => this.#applyVisibilityChange(value),
      {
        nextVisibility: value,
        previousVisibility: this.categoryVisibility,
        category: this.args.category,
        form: this.args.form,
        transientData: this.args.transientData,
      }
    );
  }

  @bind
  async loadTypes(term) {
    return this.categoryTypes.filter((type) => {
      if (type.id === DISCUSSION_TYPE_ID) {
        return false;
      }

      return type.name.toLowerCase().includes(term.toLowerCase());
    });
  }

  @action
  async onChangeCategoryTypes(field, newSelectedTypes) {
    const nextTypes = [...newSelectedTypes];

    const previousTypes = this.mapCategoryTypeIdsToTypes(field.value);

    const allowed = await runOnBeforeCategoryTypesChange({
      nextTypes,
      previousTypes,
      category: this.args.category,
      form: this.args.form,
      transientData: this.args.transientData,
    });

    if (!allowed) {
      this.typeSelectorDMenuApi?.close();
      return;
    }

    field.set(nextTypes.map((type) => type.id));
  }

  @action
  onRegisterTypeSelectorDMenuApi(api) {
    this.typeSelectorDMenuApi = api;
  }

  @action
  async onParentCategoryChange(parentCategoryId) {
    if (!parentCategoryId) {
      this.args.form.set("visibility", null);
      if (!this.isEditingExistingCategory) {
        this.#setFormPermissions([this.#everyoneFullPermission]);
      }
      return;
    }

    try {
      const result = await Category.reloadById(parentCategoryId);
      const parentCategory = this.site.updateCategory(result.category);
      parentCategory.setupGroupsAndPermissions();
      const parentPermissions = parentCategory?.permissions;

      if (parentPermissions?.length > 0) {
        const parentIsPublic =
          this.#parentPermissionsAllowEveryone(parentPermissions);

        if (!parentIsPublic) {
          this.args.form.set("visibility", null);
        }

        if (this.#shouldRetainPermissionsForParent(parentPermissions)) {
          return;
        }

        if (parentIsPublic) {
          this.#setFormPermissions([this.#everyoneFullPermission]);
          return;
        }

        const newPermissions = parentPermissions.map((p) => ({
          group_name: p.group_name,
          group_id: p.group_id,
          permission_type: p.permission_type,
        }));

        this.#setFormPermissions(newPermissions);
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
  goToSecurityTab(event) {
    if (event.target.tagName === "A") {
      event.preventDefault();
      this.args.setSelectedTab?.("security");
    }
  }

  #applyVisibilityChange(value) {
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

  #parentPermissionsAllowEveryone(parentPermissions) {
    return parentPermissions.some(
      (p) => p.group_id === AUTO_GROUPS.everyone.id
    );
  }

  #currentPermissionsAreSubsetOf(parentPermissions) {
    const parentGroupIds = new Set(parentPermissions.map((p) => p.group_id));
    return (this.permissions || []).every((p) =>
      parentGroupIds.has(p.group_id)
    );
  }

  #shouldRetainPermissionsForParent(parentPermissions) {
    if (!this.isEditingExistingCategory) {
      return false;
    }

    if (this.#parentPermissionsAllowEveryone(parentPermissions)) {
      return true;
    }

    return (
      this.#currentPermissionsArePrivate &&
      this.#currentPermissionsAreSubsetOf(parentPermissions)
    );
  }

  #setFormPermissions(permissions) {
    this.args.form.set("permissions", permissions);
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

  <template>
    {{#if (or this.isEditingExistingCategory @showAdvancedTabs)}}
      <@form.Field
        @format="max"
        @name="category_type_ids"
        @showOptional={{false}}
        @title={{i18n "category.category_types"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <DMultiSelect
            class="category-type-selector"
            id={{field.id}}
            @contentClass="category-type-selector__content"
            @loadFn={{this.loadTypes}}
            @noResultsLabel={{i18n "category.category_types_no_results"}}
            @onChange={{fn this.onChangeCategoryTypes field}}
            @onRegisterDMenuApi={{this.onRegisterTypeSelectorDMenuApi}}
            @selection={{this.mapCategoryTypeIdsToTypes field.value}}
          >
            <:result as |type|>
              <div
                class={{dConcatClass
                  "category-type-selector__result"
                  (unless (availableCategoryType type) "--unavailable")
                  (concat "--category-type-" type.id)
                }}
              >
                <div class="category-type-selector__name">
                  <span class="category-type-selector__icon">
                    {{dEmoji type.icon}}
                  </span>

                  {{type.name}}

                  {{#unless (availableCategoryType type)}}
                    <span class="category-type-selector__result-badge">
                      <PluginOutlet
                        @name="category-type-selector-result-badge"
                        @outletArgs={{lazyHash type=type}}
                      >
                        {{unavailableBadgeText type}}
                      </PluginOutlet>
                    </span>
                  {{/unless}}
                </div>
                <div class="category-type-selector__description">
                  {{type.description}}
                </div>
              </div>
            </:result>
            <:selection as |type|>
              {{type.name}}
            </:selection>
          </DMultiSelect>
        </field.Control>
      </@form.Field>
    {{/if}}

    <@form.Section
      class={{dConcatClass
        "edit-category-tab"
        "edit-category-tab-general"
        (if (eq @selectedTab "general") "active")
      }}
    >
      {{#if this.showWarning}}
        <@form.Alert @icon="triangle-exclamation" @type="warning">
          {{trustHTML
            (i18n
              "category.uncategorized_general_warning"
              settingLink=this.uncategorizedSiteSettingLink
              customizeLink=this.customizeTextContentLink
            )
          }}
        </@form.Alert>
      {{/if}}

      <CategoryNameStyle
        @category={{@category}}
        @data={{@transientData}}
        @form={{@form}}
      />

      {{#if this.showDescription}}
        <div
          {{didInsert this.registerDescriptionListener}}
          {{willDestroy this.unregisterDescriptionListener}}
        >
          <@form.Container
            class="edit-category-description-container --full"
            @title={{i18n "category.description"}}
          >
            <div
              class={{dConcatClass
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
              <DDecoratedHtml
                @className="readonly-field"
                @html={{this.categoryDescription}}
              />
            </div>

            <div class="description-actions">
              {{#if @category.topic_url}}
                <@form.Button
                  class="btn-default btn-small edit-category-description"
                  @action={{this.editCategoryDescription}}
                  @icon="pencil"
                  @isLoading={{this.loadingDescription}}
                  @label="edit"
                />
              {{/if}}
              {{#if this.descriptionOverflows}}
                <@form.Button
                  class="btn-flat btn-small toggle-description"
                  @action={{this.toggleDescriptionExpanded}}
                  @icon={{if
                    this.descriptionExpanded
                    "chevron-up"
                    "chevron-down"
                  }}
                  @label={{if
                    this.descriptionExpanded
                    "category.description_collapse"
                    "category.description_expand"
                  }}
                />
              {{/if}}
            </div>
          </@form.Container>
        </div>
      {{/if}}

      {{#unless @category.isUncategorizedCategory}}
        <@form.Field
          @format="max"
          @name="parent_category_id"
          @onSet={{this.onParentCategorySet}}
          @title={{i18n "category.subcategory_of"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <CategoryChooser
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
              @value={{@transientData.parent_category_id}}
            />
          </field.Control>
        </@form.Field>
      {{/unless}}

      {{#if @category.is_special}}
        <@form.Container
          @format="max"
          @title={{i18n "category.visibility.title"}}
        >
          <@form.Alert @type="warning">
            {{#if @category.isUncategorizedCategory}}
              {{i18n "category.uncategorized_security_warning"}}
            {{else}}
              {{i18n "category.special_warning"}}
            {{/if}}
          </@form.Alert>
        </@form.Container>
      {{else}}
        <@form.Container
          class="--radio-cards"
          @format="max"
          @title={{i18n "category.visibility.title"}}
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
                    <Condition @disabled={{true}} @name="public">
                      {{dIcon "ban"}}
                      {{i18n this.publicVisibilityLabel}}
                    </Condition>
                  </:trigger>
                </DTooltip>
              {{else}}
                <Condition @name="public">
                  {{dIcon "check"}}
                  {{i18n this.publicVisibilityLabel}}
                </Condition>
              {{/if}}
              <Condition
                @locked={{this.privateVisibilityLocked}}
                @name="group_restricted"
              >
                {{#if this.privateVisibilityLocked}}
                  {{dIcon "lock"}}
                {{else}}
                  {{dIcon "check"}}
                {{/if}}
                {{i18n "category.visibility.group_restricted"}}
              </Condition>
            </cc.Conditions>

            <cc.Contents as |Content|>
              <Content @name="group_restricted">
                <@form.Container
                  @format="max"
                  @title={{i18n "category.visibility.which_groups_can_access"}}
                >
                  <GroupChooser
                    @content={{this.availableAccessGroups}}
                    @onChange={{this.onChangeAccessGroups}}
                    @options={{hash disabled=this.isParentRestricted}}
                    @value={{this.accessGroups}}
                  />
                  {{! eslint-disable ember/template-no-invalid-interactive }}
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
      {{/if}}
    </@form.Section>
  </template>
}
