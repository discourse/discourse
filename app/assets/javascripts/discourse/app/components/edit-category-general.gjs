import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action, getProperties } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryBadge from "discourse/helpers/category-badge";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
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

  @tracked name = this.args.category.name;
  @tracked color = this.args.category.color;
  @tracked style_type = this.args.category.style_type;
  @tracked style_emoji = this.args.category.style_emoji;
  @tracked style_icon = this.args.category.style_icon;

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

  get isUpdate() {
    return !this.args.category.isNew;
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

    // if editing a category, don't include its color:
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

    const c = Category.create({
      name: this.name || i18n("category.untitled"),
      color: this.color,
      id: category.id,
      text_color: category.text_color,
      parent_category_id: parseInt(category.parent_category_id, 10),
      read_restricted: category.get("read_restricted"),
    });

    return categoryBadgeHTML(c, {
      link: false,
      previewColor: true,
      styleType: this.style_type,
      styleEmoji: this.style_emoji,
      styleIcon: this.style_icon,
    });
  }

  // We can change the parent if there are no children
  @cached
  get subCategories() {
    if (!this.isUpdate) {
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

  @action
  async save(data) {
    if (this.isUpdate) {
      this.update(data);
    } else {
      this.create(data);
    }
  }

  get formData() {
    // set the badge preview styles for new categories
    if (!this.isUpdate) {
      this.style_type = "square";
      return { style_type: "square", color: "0088CC", text_color: "FFFFFF" };
    }

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

  @bind
  async create(data) {
    try {
      const response = await ajax("/categories", {
        type: "POST",
        data,
      });
      this.router.transitionTo("discovery.category", response.category.slug);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @bind
  async update(data) {
    try {
      await ajax(`/categories/${this.args.category.id}`, {
        type: "PUT",
        data,
      });

      this.router.transitionTo("discovery.categories");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  updateField(name, value, { set }) {
    if (value) {
      set(name, value);
    } else {
      set(name, undefined);
    }
    this[name] = value;
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
    return "edit-category-tab edit-category-general " + isActive;
  }

  <template>
    <div class={{this.panelClass}}>
      {{#if this.showWarning}}
        <p class="warning">
          {{icon "triangle-exclamation"}}
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
        @onSubmit={{this.save}}
        @data={{this.formData}}
        as |form transientData|
      >
        <PluginOutlet
          @name="category-name-fields-details"
          @outletArgs={{hash category=@category}}
        >
          <form.Row as |row|>
            {{#unless @category.isUncategorizedCategory}}
              <row.Col @size={{6}}>
                <form.Field
                  @name="name"
                  @title={{i18n "category.name"}}
                  @format="large"
                  @validation="required"
                  @onSet={{fn this.updateField "name"}}
                  as |field|
                >
                  <field.Input
                    @value={{@category.name}}
                    @placeholderKey="category.name_placeholder"
                    @maxlength="50"
                    class="category-name"
                  />
                </form.Field>
              </row.Col>
            {{/unless}}

            <row.Col @size={{6}}>
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
            </row.Col>
          </form.Row>
        </PluginOutlet>

        {{#if this.canSelectParentCategory}}
          <form.Field
            @name="parent_category_id"
            @title={{i18n "category.parent"}}
            class="parent-category"
            as |field|
          >
            <field.Custom>
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
            </field.Custom>
          </form.Field>
        {{/if}}

        {{#if this.subCategories}}
          <form.Container @title={{i18n "categories.subcategories"}}>
            {{#each this.subCategories as |s|}}
              {{categoryBadge s hideParent="true"}}
            {{/each}}
          </form.Container>
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
            @format="large"
            @validation="required"
            @onSet={{fn this.updateField "style_type"}}
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
              @onSet={{fn this.updateField "style_emoji"}}
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
              @onSet={{fn this.updateField "style_icon"}}
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
                    @hexValue={{this.color}}
                    @valid={{@category.colorValid}}
                    @ariaLabelledby="background-color-label"
                  />
                  <ColorPicker
                    @colors={{this.backgroundColors}}
                    @usedColors={{this.usedBackgroundColors}}
                    @value={{this.color}}
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
    </div>
  </template>
}
