import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import ComboBox from "discourse/select-kit/components/combo-box";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryAppearance extends Component {
  @service site;

  get isDefaultSortOrder() {
    return !this.args.transientData?.sort_order;
  }

  get sortAscendingValue() {
    return this.args.transientData?.sort_ascending;
  }

  get backgroundImageUrl() {
    return this.args.transientData?.uploaded_background?.url ?? "";
  }

  get backgroundDarkImageUrl() {
    return this.args.transientData?.uploaded_background_dark?.url ?? "";
  }

  get logoImageUrl() {
    return this.args.transientData?.uploaded_logo?.url ?? "";
  }

  get logoDarkImageUrl() {
    return this.args.transientData?.uploaded_logo_dark?.url ?? "";
  }

  get isParentCategory() {
    const parentCategoryId =
      this.args.transientData?.parent_category_id ??
      this.args.category.parent_category_id;
    return this.args.category.isParent || !parentCategoryId;
  }

  @action
  onUploadDone(field, upload) {
    this.args.form.set(field, { url: upload.url, id: upload.id });
  }

  @action
  onUploadDeleted(field) {
    this.args.form.set(field, { id: null, url: null });
  }

  @action
  onSortAscendingChange(value) {
    this.args.form.set("sort_ascending", value);
  }

  get subcategoryListStyles() {
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

  get availableViews() {
    const views = ["hot", "latest", "top"].map((value) => ({
      name: i18n(`filters.${value}.title`),
      value,
    }));

    const context = {
      categoryId: this.args.category.id,
      customFields: this.args.category.custom_fields,
    };

    return applyMutableValueTransformer(
      "category-available-views",
      views,
      context
    );
  }

  get topPeriods() {
    return this.site.periods.map((value) => ({
      name: i18n(`filters.top.${value}.title`),
      value,
    }));
  }

  get listFilters() {
    return ["all", "none"].map((value) => ({
      name: i18n(`category.list_filters.${value}`),
      value,
    }));
  }

  get sortOrders() {
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
      .toSorted((a, b) => a.name.localeCompare(b.name));
  }

  get sortAscendingOption() {
    const sortAscending = this.sortAscendingValue;
    if (sortAscending === "false") {
      return false;
    }
    if (sortAscending === "true") {
      return true;
    }
    return sortAscending;
  }

  get sortAscendingOptions() {
    return [
      { name: i18n("category.sort_ascending"), value: true },
      { name: i18n("category.sort_descending"), value: false },
    ];
  }

  <template>
    <@form.Section
      class={{concatClass
        "edit-category-tab"
        "edit-category-tab-images"
        (if (eq @selectedTab "images") "active")
      }}
    >
      <@form.Container
        @title={{i18n "category.logo"}}
        @subtitle={{i18n "category.logo_description"}}
      >
        <UppyImageUploader
          @imageUrl={{this.logoImageUrl}}
          @onUploadDone={{fn this.onUploadDone "uploaded_logo"}}
          @onUploadDeleted={{fn this.onUploadDeleted "uploaded_logo"}}
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
          @imageUrl={{this.logoDarkImageUrl}}
          @onUploadDone={{fn this.onUploadDone "uploaded_logo_dark"}}
          @onUploadDeleted={{fn this.onUploadDeleted "uploaded_logo_dark"}}
          @type="category_logo_dark"
          @id="category-dark-logo-uploader"
          class="no-repeat contain-image"
        />
      </@form.Container>

      <@form.Container @title={{i18n "category.background_image"}}>
        <UppyImageUploader
          @imageUrl={{this.backgroundImageUrl}}
          @onUploadDone={{fn this.onUploadDone "uploaded_background"}}
          @onUploadDeleted={{fn this.onUploadDeleted "uploaded_background"}}
          @type="category_background"
          @id="category-background-uploader"
        />
      </@form.Container>

      <@form.Container @title={{i18n "category.background_image_dark"}}>
        <UppyImageUploader
          @imageUrl={{this.backgroundDarkImageUrl}}
          @onUploadDone={{fn this.onUploadDone "uploaded_background_dark"}}
          @onUploadDeleted={{fn
            this.onUploadDeleted
            "uploaded_background_dark"
          }}
          @type="category_background_dark"
          @id="category-dark-background-uploader"
        />
      </@form.Container>

      <@form.Field
        @name="text_color"
        @title={{i18n "category.foreground_color"}}
        @format="large"
        as |field|
      >
        <field.Color @colors={{CATEGORY_TEXT_COLORS}} />
      </@form.Field>

      <@form.Field
        @name="default_view"
        @title={{i18n "category.default_view"}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <ComboBox
            @id="category-default-view"
            @content={{this.availableViews}}
            @value={{field.value}}
            @valueProperty="value"
            @onChange={{field.set}}
            @options={{hash none="category.sort_options.default"}}
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
            @id="category-default-top-period"
            @content={{this.topPeriods}}
            @value={{field.value}}
            @valueProperty="value"
            @onChange={{field.set}}
            @options={{hash none="category.sort_options.default"}}
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
            @id="category-sort-order"
            @content={{this.sortOrders}}
            @value={{field.value}}
            @valueProperty="value"
            @onChange={{field.set}}
            @options={{hash none="category.sort_options.default"}}
          />

          {{#unless this.isDefaultSortOrder}}
            <ComboBox
              @id="category-sort-ascending"
              @content={{this.sortAscendingOptions}}
              @value={{this.sortAscendingOption}}
              @valueProperty="value"
              @onChange={{this.onSortAscendingChange}}
              @options={{hash none="category.sort_options.default"}}
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
            @id="category-default-list-filter"
            @content={{this.listFilters}}
            @value={{field.value}}
            @valueProperty="value"
            @onChange={{field.set}}
            @options={{hash none="category.sort_options.default"}}
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
                @id="subcategory-list-style"
                @content={{this.subcategoryListStyles}}
                @value={{field.value}}
                @valueProperty="value"
                @onChange={{field.set}}
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
        @outletArgs={{lazyHash category=@category form=@form}}
      />
    </@form.Section>
  </template>
}
