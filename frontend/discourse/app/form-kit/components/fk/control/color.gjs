import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { isValidHex } from "discourse/lib/color-transformations";
import getUrl from "discourse/lib/get-url";
import DColorInput from "discourse/ui-kit/d-color-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function isColorUsed(usedColors, color) {
  const normalizedColor = color.toUpperCase();
  return usedColors?.some((c) => c.toUpperCase() === normalizedColor);
}

function colorStyle(color) {
  return trustHTML(`background-color: #${color};`);
}

function colorLabel(usedColors, color) {
  const usedText = isColorUsed(usedColors, color)
    ? ` ${i18n("category.color_used")}`
    : "";
  return `#${color}${usedText}`;
}

function calculateLuminance(hex) {
  if (!hex || hex.length < 3) {
    return 1;
  }

  let normalized = hex.toUpperCase();

  if (normalized.length === 3) {
    normalized =
      normalized[0] +
      normalized[0] +
      normalized[1] +
      normalized[1] +
      normalized[2] +
      normalized[2];
  }

  const r = parseInt(normalized.slice(0, 2), 16);
  const g = parseInt(normalized.slice(2, 4), 16);
  const b = parseInt(normalized.slice(4, 6), 16);

  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

function colorLuminanceClass(color) {
  return calculateLuminance(color) > 0.5 ? "--is-light" : "--is-dark";
}

export default class FKControlColor extends FKBaseControl {
  static controlType = "color";

  @service currentUser;

  get showPrefix() {
    return this.args.prefixHex || !this.args.allowNamedColors;
  }

  get unusedColors() {
    if (!this.args.usedColors) {
      return this.args.colors;
    }

    return this.args.colors.filter(
      (color) => !isColorUsed(this.args.usedColors, color)
    );
  }

  get usedColorsFromPalette() {
    if (!this.args.usedColors) {
      return [];
    }

    return this.args.colors.filter((color) =>
      isColorUsed(this.args.usedColors, color)
    );
  }

  get sortedColors() {
    if (!this.args.usedColors) {
      return this.args.colors;
    }

    return this.args.colors.toSorted((a) =>
      isColorUsed(this.args.usedColors, a) ? 1 : -1
    );
  }

  @action
  setValue(value) {
    if (this.args.prefixHex && value && isValidHex(value.replace(/^#/, ""))) {
      value = value.startsWith("#") ? value : `#${value}`;
    }
    this.args.field.set(value);
  }

  @action
  handleBlur() {
    if (!this.args.field.value && this.args.fallbackValue) {
      this.setValue(this.args.fallbackValue);
    }
  }

  @action
  selectColor(color, closeMenu) {
    this.setValue(color);
    if (typeof closeMenu === "function") {
      closeMenu();
    }
  }

  <template>
    <div class="form-kit__control-color">
      <div class="form-kit__control-color-input">
        <DColorInput
          aria-describedby={{@field.describedBy}}
          aria-invalid={{if @field.error "true"}}
          class="form-kit__control-color-input-hex"
          id={{@field.id}}
          name={{@field.name}}
          ...attributes
          @allowNamedColors={{@allowNamedColors}}
          @disabled={{@field.disabled}}
          @hashPrefix={{this.showPrefix}}
          @onChange={{this.setValue}}
          @value={{@field.value}}
          {{on "blur" this.handleBlur}}
        />
        {{#if (and @colors @collapseSwatches)}}
          <DMenu
            class="btn-default form-kit__control-color-swatches-btn"
            @icon="palette"
            @identifier="color-swatches-menu"
            @modalForMobile={{true}}
            @title={{@collapseSwatchesLabel}}
          >
            <:content as |args|>
              <div class="form-kit__control-color-swatches" role="group">
                <div class="form-kit__control-color-swatches-label">
                  {{i18n "form_kit.color.available_presets"}}
                  {{#if this.currentUser.admin}}
                    <a
                      class="form-kit__control-color-edit-presets"
                      href={{getUrl
                        "/admin/site_settings/category/all_results?filter=category_colors"
                      }}
                      title={{i18n "form_kit.color.edit_presets"}}
                    >
                      {{i18n "edit"}}
                    </a>
                  {{/if}}
                </div>
                {{#each this.unusedColors as |color|}}
                  <button
                    aria-label={{colorLabel @usedColors color}}
                    class="form-kit__control-color-swatch"
                    data-color={{color}}
                    style={{colorStyle color}}
                    type="button"
                    {{on "click" (fn this.selectColor color args.close)}}
                  ></button>
                {{/each}}
              </div>
              {{#if this.usedColorsFromPalette.length}}
                <div
                  class="form-kit__control-color-swatches --used"
                  role="group"
                >
                  <div class="form-kit__control-color-swatches-label">
                    {{i18n "form_kit.color.already_used"}}
                  </div>
                  {{#each this.usedColorsFromPalette as |color|}}
                    <button
                      aria-label={{colorLabel @usedColors color}}
                      class={{dConcatClass
                        "form-kit__control-color-swatch"
                        "is-used"
                      }}
                      data-color={{color}}
                      style={{colorStyle color}}
                      title={{i18n "category.already_used"}}
                      type="button"
                      {{on "click" (fn this.selectColor color args.close)}}
                    >
                    </button>
                  {{/each}}
                </div>
              {{/if}}
            </:content>
          </DMenu>
        {{/if}}
      </div>

      {{#if @colors}}
        {{#unless @collapseSwatches}}
          <div class="form-kit__control-color-swatches" role="group">
            {{#each this.sortedColors as |color|}}
              <button
                aria-label={{colorLabel @usedColors color}}
                class={{dConcatClass
                  "form-kit__control-color-swatch"
                  (if (isColorUsed @usedColors color) "is-used")
                  (colorLuminanceClass color)
                }}
                data-color={{color}}
                disabled={{@field.disabled}}
                style={{colorStyle color}}
                title={{if
                  (isColorUsed @usedColors color)
                  (i18n "category.already_used")
                }}
                type="button"
                {{on "click" (fn this.selectColor color)}}
              >
                {{#if (isColorUsed @usedColors color)}}
                  {{dIcon "check"}}
                {{/if}}
              </button>
            {{/each}}
          </div>
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
