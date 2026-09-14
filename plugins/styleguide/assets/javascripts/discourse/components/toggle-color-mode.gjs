import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { loadColorSchemeStylesheet } from "discourse/lib/color-scheme-picker";
import { currentThemeId } from "discourse/lib/theme-selector";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

const DARK = "dark";
const LIGHT = "light";
const AUTO = "auto";

const AUTO_LIGHT_MEDIA = "(prefers-color-scheme: light)";
const AUTO_DARK_MEDIA = "(prefers-color-scheme: dark)";

const ICONS = {
  [LIGHT]: "sun",
  [DARK]: "moon",
  [AUTO]: "circle-half-stroke",
};

function lightSchemeStylesheet() {
  return document.querySelector("link.light-scheme");
}

function darkSchemeStylesheet() {
  return (
    document.querySelector("link.dark-scheme") ||
    document.querySelector("link#cs-preview-dark")
  );
}

/** The mode the document is currently showing, which outlives any one instance of this component. */
function appliedColorMode() {
  if (darkSchemeStylesheet()?.media === "all") {
    return DARK;
  }

  if (lightSchemeStylesheet()?.media === "all") {
    return LIGHT;
  }

  return AUTO;
}

function applyColorMode(mode) {
  const lightScheme = lightSchemeStylesheet();
  const darkScheme = darkSchemeStylesheet();

  if (!lightScheme || !darkScheme) {
    return;
  }

  switch (mode) {
    case DARK:
      lightScheme.media = "none";
      darkScheme.media = "all";
      break;
    case LIGHT:
      lightScheme.media = "all";
      darkScheme.media = "none";
      break;
    default:
      lightScheme.media = AUTO_LIGHT_MEDIA;
      darkScheme.media = AUTO_DARK_MEDIA;
      break;
  }
}

export default class ToggleColorMode extends Component {
  @service site;

  // Seeded from the document rather than from a preference, because this component is rebuilt on
  // every styleguide navigation while the mode it applied stays on the page.
  @tracked mode = appliedColorMode();
  @tracked shouldRender = true;

  constructor() {
    super(...arguments);

    // If site has a dark color scheme set but user doesn't auto switch in dark mode
    // we need to load the stylesheet manually
    if (!document.querySelector("link.dark-scheme")) {
      if (this.site.default_dark_color_scheme?.id > 0) {
        loadColorSchemeStylesheet(
          this.site.default_dark_color_scheme.id,
          currentThemeId(),
          true
        );
      } else {
        // no dark color scheme available, hide button
        this.shouldRender = false;
      }
    }
  }

  get icon() {
    return ICONS[this.mode];
  }

  @action
  select(mode, dMenu) {
    applyColorMode(mode);

    // Read back rather than assume: with the dark stylesheet still loading nothing was applied,
    // and the trigger has to keep showing the mode that is actually on screen.
    this.mode = appliedColorMode();
    dMenu.close();
  }

  <template>
    {{#if this.shouldRender}}
      <DMenu
        class="toggle-color-mode"
        data-current-mode={{this.mode}}
        @animated={{false}}
        @ariaLabel={{i18n
          "sidebar.footer.interface_color_selector.aria_label"
          mode=this.mode
        }}
        @icon={{this.icon}}
        @identifier="styleguide-color-mode"
        @title={{i18n "sidebar.footer.interface_color_selector.title"}}
        @triggerClass="btn-default btn-small"
      >
        <:content as |dMenu|>
          <DDropdownMenu as |dropdown|>
            <dropdown.item>
              <DButton
                class="toggle-color-mode__light-option"
                @action={{fn this.select LIGHT dMenu}}
                @icon="sun"
                @translatedLabel={{i18n
                  "sidebar.footer.interface_color_selector.light"
                }}
              />
            </dropdown.item>
            <dropdown.item>
              <DButton
                class="toggle-color-mode__dark-option"
                @action={{fn this.select DARK dMenu}}
                @icon="moon"
                @translatedLabel={{i18n
                  "sidebar.footer.interface_color_selector.dark"
                }}
              />
            </dropdown.item>
            <dropdown.item>
              <DButton
                class="toggle-color-mode__auto-option"
                @action={{fn this.select AUTO dMenu}}
                @icon="circle-half-stroke"
                @translatedLabel={{i18n
                  "sidebar.footer.interface_color_selector.auto"
                }}
              />
            </dropdown.item>
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
