import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action, getProperties } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
// import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryBadge from "discourse/helpers/category-badge";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import dIcon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ColorInput from "admin/components/color-input";
import CategoryChooser from "select-kit/components/category-chooser";
import ColorPicker from "./color-picker";

export default class EditCategoryGeneral extends Component {
  @service site;
  @service siteSettings;

  // @tracked textColor = this.args.category.text_color;
  @tracked categoryColor = this.args.category.color;
  @tracked styleType = this.args.category.style_type;
  @tracked styleEmoji = this.args.category.style_emoji;
  @tracked styleIcon = this.args.category.style_icon;

  uncategorizedSiteSettingLink = getURL(
    "/admin/site_settings/category/all_results?filter=allow_uncategorized_topics"
  );
  customizeTextContentLink = getURL(
    "/admin/customize/site_texts?q=uncategorized"
  );
  foregroundColors = ["FFFFFF", "000000"];

  get styleTypes() {
    return Category.styleTypes();
  }

  get showWarning() {
    return this.args.category.isUncategorizedCategory;
  }

  // background colors are available as a pipe-separated string
  @cached
  get backgroundColors() {
    const categories = this.site.get("categoriesList");
    return this.siteSettings.category_colors
      .split("|")
      .map(function (i) {
        return i.toUpperCase();
      })
      .concat(
        categories.map(function (c) {
          return c.color.toUpperCase();
        })
      )
      .uniq();
  }

  @cached
  get usedBackgroundColors() {
    const categories = this.site.get("categoriesList");
    const categoryId = this.args.category.id;
    const categoryColor = this.args.category.color;

    // If editing a category, don't include its color:
    return categories
      .map(function (c) {
        return categoryId &&
          categoryColor.toUpperCase() === c.color.toUpperCase()
          ? null
          : c.color.toUpperCase();
      }, this)
      .compact();
  }

  @cached
  get parentCategories() {
    return this.site
      .get("categoriesList")
      .filter((c) => c.level + 1 < this.siteSettings.max_category_nesting);
  }

  @cached
  get categoryBadgePreview() {
    const category = this.args.category;

    const parentCategoryId = category.parent_category_id;
    const name = category.name;
    const color = category.color;
    const textColor = category.text_color;

    const c = Category.create({
      name,
      color,
      id: category.id,
      text_color: textColor,
      parent_category_id: parseInt(parentCategoryId, 10),
      read_restricted: category.get("read_restricted"),
    });

    return categoryBadgeHTML(c, {
      link: false,
      previewColor: true,
      styleType: this.styleType,
      styleEmoji: this.styleEmoji,
      styleIcon: this.styleIcon,
    });
  }

  // We can change the parent if there are no children
  @cached
  get subCategories() {
    if (isEmpty(this.args.category)) {
      return null;
    }
    return Category.list().filterBy(
      "parent_category_id",
      this.args.category.id
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
    return false;
  }

  _focusCategoryName() {
    discourseLater(() => {
      const categoryName = document.querySelector(".category-name");
      categoryName && categoryName.focus();
    }, 25);
  }

  @action
  updatePreview(newColor) {
    console.log("updatePreview", newColor);
    this.categoryColor = newColor.replace("#", "");
  }

  @action
  async saveData() {
    // const data = {
    //   style_type: this.styleType,
    //   style_emoji: this.styleEmoji,
    //   style_icon: this.styleIcon,
    //   color: this.categoryColor,
    // };

    await this.args.category.save();
  }

  get formData() {
    // if (!this.isEditing) {
    //   return {};
    // }

    return getProperties(this.args.category, [
      "name",
      "slug",
      "parent_category_id",
      "description",
      "color",
      "text_color",
      "style_type",
      "style_emoji",
      "style_icon",
    ]);
  }

  @action
  updateStyle(value) {
    this.styleType = value;
    this.args.category.set("style_type", value);
  }

  @action
  updateEmoji(value) {
    this.styleEmoji = value;
    this.args.category.set("style_emoji", value);
  }

  @action
  updateIcon(value) {
    this.styleIcon = value;
    this.args.category.set("style_icon", value);
  }

  get categoryDescription() {
    if (this.args.category.description) {
      return htmlSafe(this.args.category.description);
    }

    return i18n("category.no_description");
  }

  <template>
    {{#if this.showWarning}}
      <p class="warning">
        {{dIcon "triangle-exclamation"}}
        {{htmlSafe
          (i18n
            "category.uncategorized_general_warning"
            settingLink=this.uncategorizedSiteSettingLink
            customizeLink=this.customizeTextContentLink
          )
        }}
      </p>
    {{/if}}

    <Form
      @onSubmit={{this.saveData}}
      @data={{this.formData}}
      {{didInsert this._focusCategoryName}}
      as |form transientData|
    >
      <PluginOutlet
        @name="category-name-fields-details"
        @outletArgs={{hash category=@category}}
      >
        {{#unless @category.isUncategorizedCategory}}
          <form.Field
            @name="name"
            @title={{i18n "category.name"}}
            @format="large"
            @validation="required"
            as |field|
          >
            <field.Input
              @value={{@category.name}}
              @placeholderKey="category.name_placeholder"
              @maxlength="50"
              class="category-name"
            />
          </form.Field>
        {{/unless}}

        <form.Field
          @name="slug"
          @title={{i18n "category.slug"}}
          @format="large"
          @validation="required"
          as |field|
        >
          <field.Input
            @value={{@category.slug}}
            @placeholderKey="category.slug_placeholder"
            @maxlength="255"
          />
        </form.Field>
      </PluginOutlet>

      {{#if this.canSelectParentCategory}}
        <section class="field parent-category">
          <label>{{i18n "category.parent"}}</label>
          <CategoryChooser
            @value={{@category.parent_category_id}}
            @allowSubCategories={{true}}
            @allowRestrictedCategories={{true}}
            @onChange={{fn (mut @category.parent_category_id)}}
            @options={{hash
              allowUncategorized=false
              excludeCategoryId=@category.id
              autoInsertNoneItem=true
              none=true
            }}
          />
        </section>
      {{/if}}

      {{#if this.subCategories}}
        <section class="field subcategories">
          <label>{{i18n "categories.subcategories"}}</label>
          {{#each this.subCategories as |s|}}
            {{categoryBadge s hideParent="true"}}
          {{/each}}
        </section>
      {{/if}}

      {{#if this.showDescription}}
        <form.Section
          @title={{i18n "category.description"}}
          @subtitle={{this.categoryDescription}}
        >
          {{#if @category.topic_url}}
            <DButton
              @action={{this.showCategoryTopic}}
              @icon="pencil"
              @label="category.change_in_category_topic"
              class="btn-default edit-category-description"
            />
          {{/if}}
        </form.Section>
      {{/if}}

      <form.Section @title={{i18n "category.style"}} class="category-style">
        {{htmlSafe this.categoryBadgePreview}}

        <form.Field
          @name="style_type"
          @title={{i18n "category.styles.type"}}
          @format="small"
          @validation="required"
          @onSet={{this.updateStyle}}
          as |field|
        >
          <field.Select as |select|>
            {{#each this.styleTypes as |styleType|}}
              <select.Option @value={{styleType.id}}>
                {{styleType.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        {{#if (eq transientData.style_type "emoji")}}
          <form.Field
            @name="style_emoji"
            @title={{i18n "category.styles.emoji"}}
            @format="small"
            @validation="required"
            @context="category-style"
            @onSet={{this.updateEmoji}}
            as |field|
          >
            <field.Emoji />
          </form.Field>
        {{else if (eq transientData.style_type "icon")}}
          <form.Field
            @name="style_icon"
            @title={{i18n "category.styles.icon"}}
            @format="small"
            @validation="required"
            @onSet={{this.updateIcon}}
            as |field|
          >
            <field.Icon />
          </form.Field>
        {{/if}}

        <div class="category-color-editor">
          <form.Field
            @name="color"
            @title={{i18n "category.background_color"}}
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Custom>
              <div class="colorpicker-wrapper edit-background-color">
                <ColorInput
                  @hexValue={{@category.color}}
                  @valid={{@category.colorValid}}
                  @ariaLabelledby="background-color-label"
                  @onChangeColor={{this.updatePreview}}
                />
                <ColorPicker
                  @colors={{this.backgroundColors}}
                  @usedColors={{this.usedBackgroundColors}}
                  @value={{@category.color}}
                  @ariaLabel={{i18n "category.predefined_colors"}}
                />
              </div>
            </field.Custom>
          </form.Field>

          <form.Field
            @name="text_color"
            @title={{i18n "category.foreground_color"}}
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Custom>
              <div class="colorpicker-wrapper edit-text-color">
                <ColorInput
                  @hexValue={{@category.text_color}}
                  @ariaLabelledby="foreground-color-label"
                />
                <ColorPicker
                  @colors={{this.foregroundColors}}
                  @value={{@category.text_color}}
                  @ariaLabel={{i18n "category.predefined_colors"}}
                />
              </div>
            </field.Custom>
          </form.Field>
        </div>
      </form.Section>

      <form.Submit @label="category.save" />
    </Form>
  </template>
}
