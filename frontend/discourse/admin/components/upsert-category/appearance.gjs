import { fn, hash } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { and, empty } from "@ember/object/computed";
import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import PluginOutlet from "discourse/components/plugin-outlet";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import lazyHash from "discourse/helpers/lazy-hash";
import { CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import discourseComputed from "discourse/lib/decorators";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryAppearance extends buildCategoryPanel(
  "images"
) {
  @and("category.show_subcategory_list", "isParentCategory")
  showSubcategoryListStyle;

  @empty("category.sort_order") isDefaultSortOrder;

  @discourseComputed("category.uploaded_background.url")
  backgroundImageUrl(uploadedBackgroundUrl) {
    return uploadedBackgroundUrl || "";
  }

  @discourseComputed("category.uploaded_background_dark.url")
  backgroundDarkImageUrl(uploadedBackgroundDarkUrl) {
    return uploadedBackgroundDarkUrl || "";
  }

  @discourseComputed("category.uploaded_logo.url")
  logoImageUrl(uploadedLogoUrl) {
    return uploadedLogoUrl || "";
  }

  @discourseComputed("category.uploaded_logo_dark.url")
  logoImageDarkUrl(uploadedLogoDarkUrl) {
    return uploadedLogoDarkUrl || "";
  }

  @action
  logoUploadDone(upload) {
    this._setFromUpload("category.uploaded_logo", upload);
  }

  @action
  logoUploadDeleted() {
    this._deleteUpload("category.uploaded_logo");
  }

  @action
  logoDarkUploadDone(upload) {
    this._setFromUpload("category.uploaded_logo_dark", upload);
  }

  @action
  logoDarkUploadDeleted() {
    this._deleteUpload("category.uploaded_logo_dark");
  }

  @action
  backgroundUploadDone(upload) {
    this._setFromUpload("category.uploaded_background", upload);
  }

  @action
  backgroundUploadDeleted() {
    this._deleteUpload("category.uploaded_background");
  }

  @action
  backgroundDarkUploadDone(upload) {
    this._setFromUpload("category.uploaded_background_dark", upload);
  }

  @action
  backgroundDarkUploadDeleted() {
    this._deleteUpload("category.uploaded_background_dark");
  }

  _deleteUpload(path) {
    this.set(
      path,
      EmberObject.create({
        id: null,
        url: null,
      })
    );
  }

  _setFromUpload(path, upload) {
    this.set(
      path,
      EmberObject.create({
        url: upload.url,
        id: upload.id,
      })
    );
  }

  @discourseComputed(
    "category.isParent",
    "category.parent_category_id",
    "transientData.parent_category_id"
  )
  isParentCategory(isParent, parentCategoryId, transientParentCategoryId) {
    return isParent || !(parentCategoryId || transientParentCategoryId);
  }

  @discourseComputed
  availableSubcategoryListStyles() {
    return [
      { name: i18n("category.subcategory_list_styles.rows"), value: "rows" },
      {
        name: i18n(
          "category.subcategory_list_styles.rows_with_featured_topics"
        ),
        value: "rows_with_featured_topics",
      },
      {
        name: i18n("category.subcategory_list_styles.boxes"),
        value: "boxes",
      },
      {
        name: i18n(
          "category.subcategory_list_styles.boxes_with_featured_topics"
        ),
        value: "boxes_with_featured_topics",
      },
    ];
  }

  @discourseComputed("category.id", "category.custom_fields")
  availableViews(categoryId, customFields) {
    const views = [
      { name: i18n("filters.latest.title"), value: "latest" },
      { name: i18n("filters.top.title"), value: "top" },
    ];

    const context = {
      categoryId,
      customFields,
    };

    return applyMutableValueTransformer(
      "category-available-views",
      views,
      context
    );
  }

  @discourseComputed
  availableTopPeriods() {
    return ["all", "yearly", "quarterly", "monthly", "weekly", "daily"].map(
      (p) => {
        return { name: i18n(`filters.top.${p}.title`), value: p };
      }
    );
  }

  @discourseComputed
  availableListFilters() {
    return ["all", "none"].map((p) => {
      return { name: i18n(`category.list_filters.${p}`), value: p };
    });
  }

  @discourseComputed
  availableSorts() {
    return applyMutableValueTransformer("category-sort-orders", [
      "likes",
      "op_likes",
      "views",
      "posts",
      "activity",
      "posters",
      "category",
      "created",
    ])
      .map((s) => ({ name: i18n("category.sort_options." + s), value: s }))
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  @discourseComputed("category.sort_ascending")
  sortAscendingOption(sortAscending) {
    if (sortAscending === "false") {
      return false;
    }
    if (sortAscending === "true") {
      return true;
    }
    return sortAscending;
  }

  @discourseComputed
  sortAscendingOptions() {
    return [
      { name: i18n("category.sort_ascending"), value: true },
      { name: i18n("category.sort_descending"), value: false },
    ];
  }

  <template>
    <@form.Container
      @title={{i18n "category.logo"}}
      @subtitle={{i18n "category.logo_description"}}
    >
      <UppyImageUploader
        @imageUrl={{this.logoImageUrl}}
        @onUploadDone={{this.logoUploadDone}}
        @onUploadDeleted={{this.logoUploadDeleted}}
        @type="category_logo"
        @id="category-logo-uploader"
        class="no-repeat contain-image"
      />
    </@form.Container>

    <@form.Container
      @title={{i18n "category.logo_dark"}}
      @subtitle={{i18n "category.logo_description"}}
    >
      <UppyImageUploader
        @imageUrl={{this.logoImageDarkUrl}}
        @onUploadDone={{this.logoDarkUploadDone}}
        @onUploadDeleted={{this.logoDarkUploadDeleted}}
        @type="category_logo_dark"
        @id="category-dark-logo-uploader"
        class="no-repeat contain-image"
      />
    </@form.Container>

    <@form.Container @title={{i18n "category.background_image"}}>
      <UppyImageUploader
        @imageUrl={{this.backgroundImageUrl}}
        @onUploadDone={{this.backgroundUploadDone}}
        @onUploadDeleted={{this.backgroundUploadDeleted}}
        @type="category_background"
        @id="category-background-uploader"
      />
    </@form.Container>

    <@form.Container @title={{i18n "category.background_image_dark"}}>
      <UppyImageUploader
        @imageUrl={{this.backgroundDarkImageUrl}}
        @onUploadDone={{this.backgroundDarkUploadDone}}
        @onUploadDeleted={{this.backgroundDarkUploadDeleted}}
        @type="category_background_dark"
        @id="category-dark-background-uploader"
      />
    </@form.Container>

    {{! This field is removed from edit-category-general when the UC is active }}
    {{#if this.siteSettings.enable_simplified_category_creation}}
      <@form.Field
        @name="text_color"
        @title={{i18n "category.foreground_color"}}
        @format="large"
        as |field|
      >
        <field.Color @colors={{CATEGORY_TEXT_COLORS}} />
      </@form.Field>
    {{/if}}

    <@form.Field
      @name="default_view"
      @title={{i18n "category.default_view"}}
      @format="large"
      as |field|
    >
      <field.Custom>
        <ComboBox
          @valueProperty="value"
          @id="category-default-view"
          @content={{this.availableViews}}
          @value={{field.value}}
          @onChange={{field.set}}
          @options={{hash placementStrategy="absolute"}}
        />
      </field.Custom>
    </@form.Field>

    <@form.Field
      @name="default_top_period"
      @title={{i18n "category.default_top_period"}}
      @format="large"
      as |field|
    >
      <field.Custom>
        <ComboBox
          @valueProperty="value"
          @id="category-default-period"
          @content={{this.availableTopPeriods}}
          @value={{field.value}}
          @onChange={{field.set}}
          @options={{hash placementStrategy="absolute"}}
        />
      </field.Custom>
    </@form.Field>

    <@form.Field
      @name="sort_order"
      @title={{i18n "category.sort_order"}}
      @format="large"
      as |field|
    >
      <field.Custom>
        <ComboBox
          @valueProperty="value"
          @content={{this.availableSorts}}
          @value={{field.value}}
          @options={{hash none="category.sort_options.default"}}
          @onChange={{field.set}}
        />
        {{#unless this.isDefaultSortOrder}}
          <ComboBox
            @valueProperty="value"
            @content={{this.sortAscendingOptions}}
            @value={{this.sortAscendingOption}}
            @options={{hash
              none="category.sort_options.default"
              placementStrategy="absolute"
            }}
            @onChange={{fn (mut @category.sort_ascending)}}
          />
        {{/unless}}
      </field.Custom>
    </@form.Field>

    <@form.Field
      @name="default_list_filter"
      @title={{i18n "category.default_list_filter"}}
      @format="large"
      as |field|
    >
      <field.Custom>
        <ComboBox
          @id="category-default-filter"
          @valueProperty="value"
          @content={{this.availableListFilters}}
          @value={{field.value}}
          @onChange={{field.set}}
        />
      </field.Custom>
    </@form.Field>

    {{#if this.isParentCategory}}
      <@form.Field
        @name="show_subcategory_list"
        @title={{i18n "category.show_subcategory_list"}}
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      {{#if @transientData.show_subcategory_list}}
        <@form.Field
          @name="subcategory_list_style"
          @title={{i18n "category.subcategory_list_style"}}
          @format="large"
          as |field|
        >
          <field.Custom>
            <ComboBox
              @valueProperty="value"
              @id="subcategory-list-style"
              @content={{this.availableSubcategoryListStyles}}
              @value={{field.value}}
              @onChange={{field.set}}
              @options={{hash placementStrategy="absolute"}}
            />
          </field.Custom>
        </@form.Field>
      {{/if}}
    {{/if}}

    <@form.Field
      @name="read_only_banner"
      @title={{i18n "category.read_only_banner"}}
      @format="large"
      as |field|
    >
      <field.Input @maxlength="255" />
    </@form.Field>

    <PluginOutlet
      @name="category-custom-images"
      @outletArgs={{lazyHash category=this.category}}
    />
  </template>
}
