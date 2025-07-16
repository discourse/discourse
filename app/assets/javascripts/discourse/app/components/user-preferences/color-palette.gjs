import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import InterfaceColorSelector from "discourse/components/interface-color-selector";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import {
  listColorSchemes,
  loadColorSchemeStylesheet,
} from "discourse/lib/color-scheme-picker";
import { listThemes } from "discourse/lib/theme-selector";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default class ColorPalette extends Component {
  @service currentUser;
  @service session;
  @service site;

  @tracked previewingColorPalette = false;
  @tracked makeColorSchemeDefault = true;
  @tracked selectedColorPaletteId = this.getSelectedColorSchemeId();

  get canPreviewColorPalette() {
    return this.currentUser.id === this.args.user.id;
  }

  get userSelectableThemes() {
    return listThemes(this.site);
  }

  get userSelectableColorPalettes() {
    return listColorSchemes(this.site);
  }

  getSelectedColorSchemeId() {
    if (!this.session.userColorSchemeId) {
      return;
    }

    const theme = this.userSelectableThemes?.find(
      (userTheme) => userTheme.id === this.args.selectedThemeId
    );

    // We don't want to display the numeric ID of a scheme
    // when it is set by the theme but not marked as user selectable
    if (
      theme?.color_scheme_id === this.session.userColorSchemeId &&
      !this.userSelectableColorPalettes.find(
        (palette) => palette.id === this.session.userColorSchemeId
      )
    ) {
      return;
    } else {
      return this.session.userColorSchemeId;
    }
  }

  @action
  undoColorSchemePreview() {
    this.selectedColorPaletteId = this.session.userColorSchemeId;
    this.previewingColorPalette = false;

    const darkStylesheet = document.querySelector("link#cs-preview-dark"),
      lightStylesheet = document.querySelector("link#cs-preview-light");
    if (darkStylesheet) {
      darkStylesheet.remove();
    }

    if (lightStylesheet) {
      lightStylesheet.remove();
    }
  }

  @action
  loadColorScheme(colorSchemeId) {
    this.selectedColorPaletteId = colorSchemeId;
    this.previewingColorPalette = this.canPreviewColorPalette;

    if (!this.canPreviewColorPalette) {
      return;
    }

    if (colorSchemeId < 0) {
      const defaultTheme = this.userSelectableThemes.find(
        (theme) => theme.id === this.args.selectedThemeId
      );

      if (defaultTheme && defaultTheme.color_scheme_id) {
        colorSchemeId = defaultTheme.color_scheme_id;
      }
    }

    loadColorSchemeStylesheet(colorSchemeId, this.args.selectedThemeId);
  }

  get currentSchemeCanBeSelected() {
    if (!this.userSelectableThemes || !this.args.selectedThemeId) {
      return false;
    }

    const theme = this.userSelectableThemes.findBy(
      "id",
      this.args.selectedThemeId
    );
    if (!theme) {
      return false;
    }

    return this.userSelectableColorPalettes.findBy("id", theme.color_scheme_id);
  }

  @action
  changeColorMode(colorMode) {
    console.log("changeColorMode", colorMode);
  }

  <template>
    <fieldset
      class="control-group color-scheme"
      data-setting-name="user-color-scheme"
    >
      <legend class="control-label">{{i18n "user.color_scheme"}}</legend>
      <div class="controls">
        <div class="control-subgroup color-palette">
          <div class="controls">
            <ComboBox
              @content={{this.userSelectableColorPalettes}}
              @value={{this.selectedColorPaletteId}}
              @onChange={{this.loadColorScheme}}
              @options={{hash
                translatedNone=(i18n "user.color_schemes.default_description")
                autoInsertNoneItem=(not this.currentSchemeCanBeSelected)
              }}
            />
          </div>
        </div>
        <div class="control-subgroup color-mode">
          <div class="controls">
            <InterfaceColorSelector @onChange={{this.changeColorMode}} />
          </div>
        </div>
      </div>
      {{#if this.previewingColorPalette}}
        {{#if this.previewingColorPalette}}
          <DButton
            @action={{this.undoColorSchemePreview}}
            @label="user.color_schemes.undo"
            @icon="arrow-rotate-left"
            class="btn-default btn-small undo-preview"
          />
        {{/if}}
        <div class="controls color-scheme-checkbox">
          <PreferenceCheckbox
            @labelKey="user.color_scheme_default_on_all_devices"
            @checked={{this.makeColorSchemeDefault}}
          />
        </div>
      {{/if}}
    </fieldset>
  </template>
}
