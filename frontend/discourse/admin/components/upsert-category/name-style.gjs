import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import {
  categoryColorError,
  categoryStyleErrors,
} from "discourse/admin/lib/category-style-validation";
import EmojiPickerContent from "discourse/components/emoji-picker/content";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import FKErrors from "discourse/form-kit/components/fk/errors";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import categoryStyleType from "discourse/lib/category-style-type";
import {
  colorBrightness,
  isValidHex,
  normalizeHex,
} from "discourse/lib/color-transformations";
import { CATEGORY_TEXT_COLORS } from "discourse/lib/constants";
import DButton from "discourse/ui-kit/d-button";
import DIconGridPickerContent from "discourse/ui-kit/d-icon-grid-picker/content";
import DTabs from "discourse/ui-kit/d-tabs";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const EMOJI_TONES = {
  t2: "emoji_picker.light_tone",
  t3: "emoji_picker.medium_light_tone",
  t4: "emoji_picker.medium_tone",
  t5: "emoji_picker.medium_dark_tone",
  t6: "emoji_picker.dark_tone",
};

class ColorField extends Component {
  @tracked isEditing = false;

  @action
  finishEditing() {
    this.isEditing = false;
    this.args.onBlur();
  }

  <template>
    <@form.Field
      class="category-name-style__color"
      @name="color"
      @onSet={{@onSet}}
      @showTitle={{false}}
      @title={{i18n "category.background_color"}}
      @type="color"
      as |field|
    >
      {{#let
        (unless this.isEditing (categoryColorError field.value))
        as |error|
      }}
        <field.Control
          aria-describedby={{if error field.errorId field.describedBy}}
          aria-invalid={{if error "true"}}
          aria-label={{field.title}}
          @collapseSwatches={{true}}
          @collapseSwatchesLabel={{i18n "category.color_palette"}}
          @colors={{@colors}}
          @fallbackValue={{@category.color}}
          @usedColors={{@usedColors}}
          {{on "focus" (fn (mut this.isEditing) true)}}
          {{on "blur" this.finishEditing}}
        >
          <:prefix>
            {{#if error}}
              <DTooltip role="presentation">
                <:trigger>
                  <DButton
                    class="btn-transparent category-name-style__color-warning"
                    @icon="triangle-exclamation"
                    @translatedAriaLabel={{error}}
                  />
                </:trigger>
                <:content>{{error}}</:content>
              </DTooltip>
            {{else}}
              #
            {{/if}}
          </:prefix>
        </field.Control>
        {{#if error}}
          <FKErrors
            class="sr-only"
            @error={{hash messages=(array error)}}
            @id={{field.errorId}}
          />
        {{/if}}
      {{/let}}
    </@form.Field>
  </template>
}

export default class CategoryNameStyle extends Component {
  @service site;
  @service siteSettings;

  get styleType() {
    return categoryStyleType(this.args.data.style_type) || "square";
  }

  get triggerTitle() {
    const type = this.styleType;
    const { icon, emoji } = this.args.data;
    if (type === "icon" && icon) {
      return i18n("category.choose_style_with_icon", {
        name: icon.replace(/^fa[brs]-/, "").replace(/[-_]/g, " "),
      });
    }
    if (type === "emoji" && emoji) {
      const [base, tone] = emoji.split(":");
      const name = base.replace(/(?<=\w)[-_]/g, " ");
      return EMOJI_TONES[tone]
        ? i18n("category.choose_style_with_emoji_tone", {
            name,
            tone: i18n(EMOJI_TONES[tone]),
          })
        : i18n("category.choose_style_with_emoji", { name });
    }
    return i18n("category.choose_style", {
      style: i18n(`category.styles.${type}`),
    });
  }

  get iconColorStyle() {
    const color = this.args.data.color;
    if (isValidHex(color)) {
      return trustHTML(`--icon-color: #${normalizeHex(color)}`);
    }
  }

  get backgroundColors() {
    return uniqueItemsFromArray(
      this.siteSettings.category_colors
        .split("|")
        .filter(Boolean)
        .concat(this.site.categoriesList.map((category) => category.color))
        .map((color) => color.toUpperCase())
    );
  }

  get usedBackgroundColors() {
    return this.site.categoriesList
      .filter((category) => category.id !== this.args.category.id)
      .map((category) => category.color.toUpperCase());
  }

  @action
  revalidateStyle(style) {
    if (style.error) {
      style.removeError();
      for (const error of categoryStyleErrors(this.args.data)) {
        style.addError(style.name, error);
      }
    }
  }

  @action
  async setStyleValue(style, name, value) {
    await this.args.form.set(name, value);
    this.revalidateStyle(style);
  }

  @action
  async setColor(style, value, { set }) {
    const color = value?.replace(/^#/, "") ?? "";
    await set("color", color);

    if (isValidHex(color)) {
      const light = colorBrightness(color) > 127.5;
      await set("text_color", CATEGORY_TEXT_COLORS[light ? 1 : 0]);
      this.revalidateStyle(style);
    }
  }

  <template>
    <@form.Field
      class="category-name-style"
      ...attributes
      @format="max"
      @name="style_type"
      @showTitle={{false}}
      @title={{i18n "category.style"}}
      @type="custom"
      as |style|
    >
      <@form.Field
        class="category-name-style__name"
        @disabled={{@category.isUncategorizedCategory}}
        @format="max"
        @name="name"
        @title={{i18n "category.name_and_style"}}
        @type="input"
        @validation="required"
        as |field|
      >
        <div class="category-name-style__row">
          <DMenu
            aria-describedby={{style.describedBy}}
            aria-invalid={{if style.error "true"}}
            style={{this.iconColorStyle}}
            @ariaLabel={{this.triggerTitle}}
            @identifier="category-style"
            @inlineTabOrder={{true}}
            @title={{this.triggerTitle}}
            @triggerClass="btn-default category-name-style__trigger"
          >
            <:trigger>
              <span class="category-name-style__preview">
                {{#if (eq this.styleType "emoji")}}
                  {{#if @data.emoji}}
                    {{dEmoji @data.emoji}}
                  {{else}}
                    {{dIcon "far-face-smile"}}
                  {{/if}}
                {{else if (eq this.styleType "icon")}}
                  {{dIcon (or @data.icon "square-full") ignoreMissing=true}}
                {{else}}
                  <span class="category-name-style__square"></span>
                {{/if}}
              </span>
            </:trigger>
            <:content as |menu|>
              {{#let
                (component
                  ColorField
                  form=@form
                  category=@category
                  onBlur=(fn this.revalidateStyle style)
                  onSet=(fn this.setColor style)
                  colors=this.backgroundColors
                  usedColors=this.usedBackgroundColors
                )
                as |Color|
              }}
                <DTabs
                  class="category-name-style__tabs"
                  @active={{this.styleType}}
                  @label={{i18n "category.style"}}
                  @onActivate={{fn this.setStyleValue style "style_type"}}
                  as |tabs|
                >
                  <tabs.Tab @key="icon" @label={{i18n "category.styles.icon"}}>
                    <DIconGridPickerContent
                      @iconColorStyle={{this.iconColorStyle}}
                      @onSelect={{fn this.setStyleValue style "icon"}}
                      @searchPlaceholder={{i18n
                        "category.icon_search_placeholder"
                      }}
                      @showNames={{true}}
                      @value={{@data.icon}}
                    >
                      <Color />
                    </DIconGridPickerContent>
                  </tabs.Tab>
                  {{#if this.siteSettings.enable_emoji}}
                    <tabs.Tab
                      @key="emoji"
                      @label={{i18n "category.styles.emoji"}}
                    >
                      <EmojiPickerContent
                        @close={{menu.close}}
                        @compact={{true}}
                        @context="topic"
                        @didSelectEmoji={{fn this.setStyleValue style "emoji"}}
                        @selected={{@data.emoji}}
                      />
                    </tabs.Tab>
                  {{/if}}
                  <tabs.Tab
                    @key="square"
                    @label={{i18n "category.styles.square"}}
                  >
                    <Color />
                  </tabs.Tab>
                </DTabs>
              {{/let}}
            </:content>
          </DMenu>
          <field.Control
            class="category-name"
            data-1p-ignore
            placeholder={{i18n "category.name_placeholder"}}
            @maxlength="50"
          />
        </div>
      </@form.Field>
    </@form.Field>
  </template>
}
