import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryBadge from "discourse/helpers/category-badge";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import { CATEGORY_STYLE_TYPES } from "discourse/lib/constants";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ColorInput from "admin/components/color-input";
import CategoryChooser from "select-kit/components/category-chooser";
import ColorPicker from "./color-picker";

export default class EditCategoryGeneral extends Component {
  @service router;
  @service site;
  @service siteSettings;

  uncategorizedSiteSettingLink = getURL(
    "/admin/site_settings/category/all_results?filter=allow_uncategorized_topics"
  );
  customizeTextContentLink = getURL(
    "/admin/customize/site_texts?q=uncategorized"
  );

  get styleTypes() {
    return Object.keys(CATEGORY_STYLE_TYPES).map((key) => ({
      id: key,
      name: i18n(`category.styles.options.${key}`),
    }));
  }

  get showWarning() {
    return this.args.category.isUncategorizedCategory;
  }

  @cached
  get backgroundColors() {
    const categories = this.site.get("categoriesList");
    return this.siteSettings.category_colors
      .split("|")
      .filter(Boolean)
      .map((i) => i.toUpperCase())
      .concat(categories.map((c) => c.color.toUpperCase()))
      .uniq();
  }

  @cached
  get usedBackgroundColors() {
    const categories = this.site.get("categoriesList");
    const categoryId = this.args.category.id;
    const categoryColor = this.args.category.color;

    // if editing a category, don't include its color:
    return categories
      .map((c) => {
        return categoryId &&
          categoryColor.toUpperCase() === c.color.toUpperCase()
          ? null
          : c.color.toUpperCase();
      })
      .compact();
  }

  @cached
  get parentCategories() {
    return this.site
      .get("categoriesList")
      .filter((c) => c.level + 1 < this.siteSettings.max_category_nesting);
  }

  @action
  categoryBadgePreview(transientData) {
    const category = this.args.category;

    const previewCategory = Category.create({
      name: transientData.name || i18n("category.untitled"),
      color: transientData.color,
      id: category.id,
      text_color: category.text_color,
      parent_category_id: parseInt(category.get("parent_category_id"), 10),
      read_restricted: category.get("read_restricted"),
    });

    return categoryBadgeHTML(previewCategory, {
      link: false,
      previewColor: true,
      styleType: transientData.style_type,
      emoji: transientData.emoji,
      icon: transientData.icon,
    });
  }

  // We can change the parent if there are no children
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
  updateColor(field, newColor) {
    field.set(newColor.replace("#", ""));
  }

  get categoryDescription() {
    if (this.args.category.description) {
      return htmlSafe(this.args.category.description);
    }

    return i18n("category.no_description");
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

      <PluginOutlet
        @name="category-name-fields-details"
        @outletArgs={{hash form=@form category=@category}}
      >
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

        <@form.Field
          @name="slug"
          @title={{i18n "category.slug"}}
          @format="large"
          as |field|
        >
          <field.Input
            placeholder={{i18n "category.slug_placeholder"}}
            @maxlength="255"
          />
        </@form.Field>
      </PluginOutlet>

      {{#if this.canSelectParentCategory}}
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
      {{/if}}

      {{#if this.subCategories}}
        <@form.Container @title={{i18n "categories.subcategories"}}>
          {{#each this.subCategories as |s|}}
            {{categoryBadge s hideParent="true"}}
          {{/each}}
        </@form.Container>
      {{/if}}

      {{#if this.showDescription}}
        <@form.Section @title={{i18n "category.description"}}>
          {{#if @category.topic_url}}
            <@form.Container @subtitle={{this.categoryDescription}}>
              <@form.Button
                @action={{this.showCategoryTopic}}
                @icon="pencil"
                @label="category.change_in_category_topic"
                class="btn-default edit-category-description"
              />
            </@form.Container>
          {{/if}}
        </@form.Section>
      {{/if}}

      <@form.Section @title={{i18n "category.style"}} class="category-style">
        <@form.Field
          @name="style_type"
          @title={{i18n "category.styles.type"}}
          @format="large"
          @validation="required"
          as |field|
        >
          {{htmlSafe (this.categoryBadgePreview @transientData)}}
          <field.Select as |select|>
            {{#each this.styleTypes as |styleType|}}
              <select.Option @value={{styleType.id}}>
                {{styleType.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </@form.Field>

        {{#if (eq @transientData.style_type "emoji")}}
          <@form.Field
            @name="emoji"
            @title={{i18n "category.styles.emoji"}}
            @format="small"
            @validation="required"
            as |field|
          >
            <field.Emoji />
          </@form.Field>
        {{else if (eq @transientData.style_type "icon")}}
          <@form.Field
            @name="icon"
            @title={{i18n "category.styles.icon"}}
            @format="small"
            @validation="required"
            as |field|
          >
            <field.Icon />
          </@form.Field>
        {{/if}}

        <@form.Field
          @name="color"
          @title={{i18n "category.background_color"}}
          @format="full"
          as |field|
        >
          <field.Custom>
            <div class="category-color-editor">
              <div class="colorpicker-wrapper edit-background-color">
                <ColorInput
                  @hexValue={{readonly field.value}}
                  @valid={{@category.colorValid}}
                  @ariaLabelledby="background-color-label"
                  @onChangeColor={{fn this.updateColor field}}
                />
                <ColorPicker
                  @colors={{this.backgroundColors}}
                  @usedColors={{this.usedBackgroundColors}}
                  @value={{readonly field.value}}
                  @ariaLabel={{i18n "category.predefined_colors"}}
                  @onSelectColor={{fn this.updateColor field}}
                />
              </div>
            </div>
          </field.Custom>
        </@form.Field>
      </@form.Section>
    </div>
  </template>
}
