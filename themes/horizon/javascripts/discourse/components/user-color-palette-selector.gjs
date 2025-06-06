import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { reload } from "discourse/helpers/page-reloader";
import { ajax } from "discourse/lib/ajax";
import {
  listColorSchemes,
  updateColorSchemeCookie,
} from "discourse/lib/color-scheme-picker";
import cookie from "discourse/lib/cookie";
import DMenu from "float-kit/components/d-menu";
import UserColorPaletteMenuItem from "./user-color-palette-menu-item";

const HORIZON_PALETTES = [
  "Horizon",
  "Marigold",
  "Violet",
  "Lily",
  "Clover",
  "Royal",
];

export default class UserColorPaletteSelector extends Component {
  @service currentUser;
  @service keyValueStore;
  @service site;
  @service session;
  @service interfaceColor;

  @tracked anonColorPaletteId = this.#loadAnonColorPalette();
  @tracked userColorPaletteId = this.session.userColorSchemeId;
  @tracked cssLoaded = true;

  get userColorPalettes() {
    const availablePalettes = listColorSchemes(this.site)
      ?.map((userPalette) => {
        return {
          ...userPalette,
          accent: `#${
            userPalette.colors.find((color) => color.name === "tertiary").hex
          }`,
        };
      })
      .filter((userPalette) => {
        return HORIZON_PALETTES.some((palette) => {
          return userPalette.name.toLowerCase().includes(palette.toLowerCase());
        });
      })
      .sort();

    // Match the light scheme with the corresponding dark id based in the name
    return (
      availablePalettes
        ?.map((palette) => {
          if (palette.is_dark) {
            return palette;
          }

          const normalizedLightName = palette.name.toLowerCase();

          const correspondingDarkModeId = availablePalettes.find(
            (item) =>
              item.is_dark &&
              normalizedLightName ===
                item.name.toLowerCase().replace(/\s+dark$/, "")
          )?.id;

          return {
            ...palette,
            correspondingDarkModeId,
          };
        })
        // Only want to show palettes that have corresponding light/dark modes
        .filter((palette) => !palette.is_dark)
    );
  }

  get selectedColorPaletteId() {
    if (this.currentUser) {
      return this.userColorPaletteId;
    }

    return this.anonColorPaletteId;
  }

  @action
  onRegisterMenu(api) {
    this.dMenu = api;
  }

  @action
  paletteSelected(selectedPalette) {
    if (selectedPalette.id === this.selectedColorPaletteId) {
      return;
    }

    this.#updatePreference(selectedPalette);
    this.#changeSiteColorPalette(selectedPalette);
    this.dMenu.close();
  }

  #updatePreference(selectedPalette) {
    updateColorSchemeCookie(selectedPalette.id);
    updateColorSchemeCookie(selectedPalette.correspondingDarkModeId, {
      dark: true,
    });

    if (!this.currentUser) {
      this.anonColorPaletteId = selectedPalette.id;
    } else {
      this.userColorPaletteId = selectedPalette.id;
    }
  }

  #loadAnonColorPalette() {
    const storedAnonPaletteId = cookie("color_scheme_id");
    if (storedAnonPaletteId) {
      return parseInt(storedAnonPaletteId, 10);
    }
  }

  async #changeSiteColorPalette(colorPalette) {
    this.cssLoaded = false;

    const lightPaletteId = colorPalette.id;
    const darkPaletteId = colorPalette.correspondingDarkModeId;
    const darkTag = document.querySelector("link.dark-scheme");

    // TODO(osama) once we have built-in light/dark modes for each palette, we
    // can stop making the 2nd ajax call for the dark palette and replace it
    // with a include_dark_scheme param on the ajax call for the light
    // palette which will include the href for the dark palette in the response
    if (!darkTag) {
      reload();
      return;
    }

    const lightPaletteInfo = await ajax(
      `/color-scheme-stylesheet/${lightPaletteId}/${colorPalette.theme_id}.json`
    );
    const darkPaletteInfo = await ajax(
      `/color-scheme-stylesheet/${darkPaletteId}/${colorPalette.theme_id}.json`
    );

    Promise.all([
      this.#preloadAndSwapCSS(lightPaletteInfo.new_href, "light-scheme"),
      this.#preloadAndSwapCSS(darkPaletteInfo.new_href, "dark-scheme"),
    ]).then(() => {
      this.cssLoaded = true;
    });
  }

  #preloadAndSwapCSS(newHref, existingLinkClass) {
    return new Promise((resolve) => {
      const existingLink = document.querySelector(
        `link[rel='stylesheet'].${existingLinkClass}`
      );
      const newTag = document.createElement("link");

      newTag.rel = "preload";
      newTag.href = newHref;
      newTag.as = "style";
      newTag.onload = () => {
        existingLink.href = newHref;
        newTag.remove();
        resolve();
      };

      document.head.appendChild(newTag);
    });
  }

  <template>
    {{#unless (isEmpty this.userColorPalettes)}}
      <DMenu
        @identifier="user-color-palette-selector"
        @placementStrategy="fixed"
        @onRegisterApi={{this.onRegisterMenu}}
        class={{concatClass
          "btn-flat user-color-palette-selector sidebar-footer-actions-button"
          (if this.cssLoaded "user-color-palette-css-loaded")
        }}
        data-selected-color-palette-id={{this.selectedColorPaletteId}}
        @inline={{true}}
      >
        <:trigger>
          {{icon "paintbrush"}}
        </:trigger>
        <:content>
          <div class="user-color-palette-menu">
            <div class="user-color-palette-menu__content">
              {{#each this.userColorPalettes as |colorPalette|}}
                <UserColorPaletteMenuItem
                  @selectedColorPaletteId={{this.selectedColorPaletteId}}
                  @colorPalette={{colorPalette}}
                  @paletteSelected={{this.paletteSelected}}
                />
              {{/each}}
            </div>
          </div>
        </:content>
      </DMenu>
    {{/unless}}
  </template>
}
