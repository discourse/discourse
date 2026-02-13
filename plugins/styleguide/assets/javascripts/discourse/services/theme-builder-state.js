import { tracked } from "@glimmer/tracking";
import { cancel, debounce } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { loadColorSchemeStylesheet } from "discourse/lib/color-scheme-picker";
import KeyValueStore from "discourse/lib/key-value-store";

const STORE_NAMESPACE = "discourse_theme_builder_";
const DEBOUNCE_MS = 800;

const DEFAULT_LIGHT_COLORS = {
  primary: "222222",
  secondary: "ffffff",
  tertiary: "0088cc",
  selected: "0088cc",
  hover: "d4f0ff",
  quaternary: "e45735",
  header_background: "ffffff",
  header_primary: "333333",
  highlight: "ffff4d",
  danger: "e45735",
  success: "009900",
  love: "fa6c8d",
};

const DEFAULT_DARK_COLORS = {
  primary: "dddddd",
  secondary: "222222",
  tertiary: "0088cc",
  selected: "0088cc",
  hover: "313131",
  quaternary: "e45735",
  header_background: "333333",
  header_primary: "dddddd",
  highlight: "a87137",
  danger: "e45735",
  success: "009900",
  love: "fa6c8d",
};

const COLOR_NAMES = [
  "primary",
  "secondary",
  "tertiary",
  "selected",
  "hover",
  "quaternary",
  "header_background",
  "header_primary",
  "highlight",
  "danger",
  "success",
  "love",
];

const DEFAULT_CUSTOM_SCSS = `:root {
  --space: 0.25rem;
  --d-border-radius: 4px;
  --d-border-radius-large: 8px;
  --d-input-border-radius: 4px;
  --d-button-border-radius: 4px;
  --d-nav-pill-border-radius: 4px;
  --d-tag-border-radius: 3px;
  --d-sidebar-border-color: transparent;
}`;

const DEFAULT_COLOR_DEFINITIONS_SCSS = `// uncomment the line below to disable the header bottom border
// --shadow-header: 0;`;

export { COLOR_NAMES, DEFAULT_COLOR_DEFINITIONS_SCSS, DEFAULT_CUSTOM_SCSS };

export default class ThemeBuilderState extends Service {
  @service currentUser;

  @tracked isOpen = false;
  @tracked activeTab = "light-colors";
  @tracked isCompiling = false;

  @tracked panelTop = 60;
  @tracked panelLeft = null;

  @tracked themeId = null;
  @tracked lightSchemeId = null;
  @tracked darkSchemeId = null;

  @tracked themeName = null;
  @tracked lightColors = { ...DEFAULT_LIGHT_COLORS };
  @tracked darkColors = { ...DEFAULT_DARK_COLORS };
  @tracked customScss = DEFAULT_CUSTOM_SCSS;
  @tracked colorDefinitionsScss = DEFAULT_COLOR_DEFINITIONS_SCSS;

  _store = new KeyValueStore(STORE_NAMESPACE);
  _debounceTimer = null;
  _compileInProgress = false;
  _pendingCompile = false;
  _loaded = false;

  get isAdmin() {
    return this.currentUser?.admin;
  }

  get hasDraft() {
    return !!this.themeId;
  }

  get themeAdminUrl() {
    if (!this.themeId) {
      return null;
    }
    return `/admin/customize/themes/${this.themeId}`;
  }

  get tabs() {
    return [
      {
        id: "light-colors",
        label: "styleguide.theme_builder.tabs.light_colors",
      },
      { id: "dark-colors", label: "styleguide.theme_builder.tabs.dark_colors" },
      { id: "css", label: "styleguide.theme_builder.tabs.css" },
      {
        id: "color-definitions",
        label: "styleguide.theme_builder.tabs.color_definitions",
      },
    ];
  }

  toggle() {
    if (!this._loaded) {
      this._loadFromStore();
      this._loaded = true;
    }
    this.isOpen = !this.isOpen;
  }

  async _loadFromExistingTheme(previewThemeId) {
    try {
      const themeData = await ajax(`/admin/themes/${previewThemeId}.json`);
      const theme = themeData.theme;

      this.themeId = theme.id;
      this.themeName = theme.name;
      this.lightSchemeId = theme.color_scheme_id;
      this.darkSchemeId = theme.dark_color_scheme_id;

      if (theme.color_scheme?.colors) {
        const lightColors = { ...DEFAULT_LIGHT_COLORS };
        for (const color of theme.color_scheme.colors) {
          if (COLOR_NAMES.includes(color.name)) {
            lightColors[color.name] = color.hex;
          }
        }
        this.lightColors = lightColors;
      }

      if (this.darkSchemeId) {
        try {
          const darkSchemeData = await ajax(
            `/admin/color_schemes/${this.darkSchemeId}.json`
          );
          const darkColors = { ...DEFAULT_DARK_COLORS };
          if (darkSchemeData.colors) {
            for (const color of darkSchemeData.colors) {
              if (COLOR_NAMES.includes(color.name)) {
                darkColors[color.name] = color.hex;
              }
            }
          }
          this.darkColors = darkColors;
        } catch {
          // dark scheme may not be accessible, use defaults
        }
      }

      const scssField = theme.theme_fields?.find(
        (f) => f.name === "scss" && f.target === "common"
      );
      if (scssField?.value) {
        this.customScss = scssField.value;
      }

      const colorDefsField = theme.theme_fields?.find(
        (f) => f.name === "color_definitions" && f.target === "common"
      );
      if (colorDefsField?.value) {
        this.colorDefinitionsScss = colorDefsField.value;
      }

      this._persistToStore();
    } catch {
      // theme may not exist or not be accessible
    }
  }

  setActiveTab(tabId) {
    this.activeTab = tabId;
  }

  setLightColor(name, hex) {
    this.lightColors = { ...this.lightColors, [name]: hex.replace(/^#/, "") };
    if (!this.themeName) {
      this._scheduleCompile();
    }
  }

  setDarkColor(name, hex) {
    this.darkColors = { ...this.darkColors, [name]: hex.replace(/^#/, "") };
    if (!this.themeName) {
      this._scheduleCompile();
    }
  }

  setCustomScss(value) {
    this.customScss = value;
  }

  setColorDefinitionsScss(value) {
    this.colorDefinitionsScss = value;
  }

  _scheduleCompile() {
    this._debounceTimer = debounce(this, this._compile, DEBOUNCE_MS);
  }

  async update() {
    await this._compile();
  }

  async _compile() {
    if (this._compileInProgress) {
      this._pendingCompile = true;
      return;
    }

    this._compileInProgress = true;
    this.isCompiling = true;
    this._persistToStore();

    try {
      if (!this.themeId) {
        await this._createDraftResources();
      } else {
        await this._updateDraftResources();
      }
      this._reloadStylesheets();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this._compileInProgress = false;
      if (this._pendingCompile) {
        this._pendingCompile = false;
        this._compile();
      } else {
        this.isCompiling = false;
      }
    }
  }

  async _createDraftResources() {
    const lightScheme = await ajax("/admin/color_schemes.json", {
      type: "POST",
      data: JSON.stringify({
        color_scheme: {
          name: "[Draft] Theme Builder Light",
          base_scheme_id: "Light",
          colors: COLOR_NAMES.map((name) => ({
            name,
            hex: this.lightColors[name],
          })),
        },
      }),
      dataType: "json",
      contentType: "application/json",
    });
    this.lightSchemeId = lightScheme.id;

    const darkScheme = await ajax("/admin/color_schemes.json", {
      type: "POST",
      data: JSON.stringify({
        color_scheme: {
          name: "[Draft] Theme Builder Dark",
          base_scheme_id: "Dark",
          colors: COLOR_NAMES.map((name) => ({
            name,
            hex: this.darkColors[name],
          })),
        },
      }),
      dataType: "json",
      contentType: "application/json",
    });
    this.darkSchemeId = darkScheme.id;

    const theme = await ajax("/admin/themes.json", {
      type: "POST",
      data: JSON.stringify({
        theme: {
          name: "[Draft] Theme Builder",
          color_scheme_id: this.lightSchemeId,
        },
      }),
      dataType: "json",
      contentType: "application/json",
    });
    this.themeId = theme.theme.id;

    await ajax(`/admin/themes/${this.themeId}.json`, {
      type: "PUT",
      data: JSON.stringify({
        theme: {
          dark_color_scheme_id: this.darkSchemeId,
          theme_fields: this._buildThemeFields(),
        },
      }),
      dataType: "json",
      contentType: "application/json",
    });

    this._persistToStore();
  }

  async _updateDraftResources() {
    if (this.lightSchemeId) {
      await ajax(`/admin/color_schemes/${this.lightSchemeId}.json`, {
        type: "PUT",
        data: JSON.stringify({
          color_scheme: {
            colors: COLOR_NAMES.map((name) => ({
              name,
              hex: this.lightColors[name],
            })),
          },
        }),
        dataType: "json",
        contentType: "application/json",
      });
    }

    if (this.darkSchemeId) {
      await ajax(`/admin/color_schemes/${this.darkSchemeId}.json`, {
        type: "PUT",
        data: JSON.stringify({
          color_scheme: {
            colors: COLOR_NAMES.map((name) => ({
              name,
              hex: this.darkColors[name],
            })),
          },
        }),
        dataType: "json",
        contentType: "application/json",
      });
    }

    await ajax(`/admin/themes/${this.themeId}.json`, {
      type: "PUT",
      data: JSON.stringify({
        theme: {
          theme_fields: this._buildThemeFields(),
        },
      }),
      dataType: "json",
      contentType: "application/json",
    });
  }

  _buildThemeFields() {
    const fields = [];

    if (this.customScss) {
      fields.push({
        name: "scss",
        target: "common",
        value: this.customScss,
        type_id: 1,
      });
    }

    if (this.colorDefinitionsScss) {
      fields.push({
        name: "color_definitions",
        target: "common",
        value: this.colorDefinitionsScss,
        type_id: 1,
      });
    }

    return fields;
  }

  async _reloadStylesheets() {
    const url = new URL(window.location.href);
    if (
      this.themeId &&
      url.searchParams.get("preview_theme_id") !== String(this.themeId)
    ) {
      url.searchParams.set("preview_theme_id", this.themeId);
      window.history.replaceState(null, "", url.toString());
    }

    if (this.lightSchemeId) {
      await loadColorSchemeStylesheet(this.lightSchemeId, this.themeId, false);
    }

    if (this.darkSchemeId) {
      await loadColorSchemeStylesheet(this.darkSchemeId, this.themeId, true);
    }
  }

  async saveAsTheme(name) {
    if (!this.themeId) {
      return;
    }

    try {
      if (this._debounceTimer) {
        cancel(this._debounceTimer);
        this._debounceTimer = null;
      }
      await this._updateDraftResources();

      if (this.lightSchemeId) {
        await ajax(`/admin/color_schemes/${this.lightSchemeId}.json`, {
          type: "PUT",
          data: JSON.stringify({
            color_scheme: { name: `${name} Light` },
          }),
          dataType: "json",
          contentType: "application/json",
        });
      }

      if (this.darkSchemeId) {
        await ajax(`/admin/color_schemes/${this.darkSchemeId}.json`, {
          type: "PUT",
          data: JSON.stringify({
            color_scheme: { name: `${name} Dark` },
          }),
          dataType: "json",
          contentType: "application/json",
        });
      }

      await ajax(`/admin/themes/${this.themeId}.json`, {
        type: "PUT",
        data: JSON.stringify({
          theme: {
            name,
            user_selectable: true,
          },
        }),
        dataType: "json",
        contentType: "application/json",
      });

      this.themeName = name;
      this._persistToStore();
      this._reloadStylesheets();
    } catch (e) {
      popupAjaxError(e);
      throw e;
    }
  }

  async reset() {
    if (this._debounceTimer) {
      cancel(this._debounceTimer);
    }

    try {
      if (this.themeId) {
        await ajax(`/admin/themes/${this.themeId}.json`, { type: "DELETE" });
      }
      if (this.lightSchemeId) {
        await ajax(`/admin/color_schemes/${this.lightSchemeId}`, {
          type: "DELETE",
        });
      }
      if (this.darkSchemeId) {
        await ajax(`/admin/color_schemes/${this.darkSchemeId}`, {
          type: "DELETE",
        });
      }
    } catch {
      // draft resources may already be deleted
    }

    this.themeId = null;
    this.themeName = null;
    this.lightSchemeId = null;
    this.darkSchemeId = null;
    this.lightColors = { ...DEFAULT_LIGHT_COLORS };
    this.darkColors = { ...DEFAULT_DARK_COLORS };
    this.customScss = DEFAULT_CUSTOM_SCSS;
    this.colorDefinitionsScss = DEFAULT_COLOR_DEFINITIONS_SCSS;
    this.isCompiling = false;

    this._clearStore();

    const url = new URL(window.location.href);
    if (url.searchParams.has("preview_theme_id")) {
      url.searchParams.delete("preview_theme_id");
      window.history.replaceState(null, "", url.toString());
      window.location.reload();
    }
  }

  _persistToStore() {
    this._store.set({
      key: "themeId",
      value: this.themeId,
    });
    this._store.set({
      key: "themeName",
      value: this.themeName,
    });
    this._store.set({
      key: "lightSchemeId",
      value: this.lightSchemeId,
    });
    this._store.set({
      key: "darkSchemeId",
      value: this.darkSchemeId,
    });
    this._store.setObject({
      key: "lightColors",
      value: this.lightColors,
    });
    this._store.setObject({
      key: "darkColors",
      value: this.darkColors,
    });
    this._store.set({
      key: "customScss",
      value: this.customScss,
    });
    this._store.set({
      key: "colorDefinitionsScss",
      value: this.colorDefinitionsScss,
    });
  }

  _loadFromStore() {
    const url = new URL(window.location.href);
    const urlThemeId = url.searchParams.get("preview_theme_id");

    if (urlThemeId) {
      const parsedUrlThemeId = parseInt(urlThemeId, 10);
      const storedThemeId = parseInt(this._store.get("themeId"), 10) || null;

      if (parsedUrlThemeId && parsedUrlThemeId === storedThemeId) {
        this._restoreFromStore();
      } else if (parsedUrlThemeId) {
        this._loadFromExistingTheme(parsedUrlThemeId);
      }
      return;
    }

    this._restoreFromStore();

    if (this.themeId) {
      url.searchParams.set("preview_theme_id", this.themeId);
      window.history.replaceState(null, "", url.toString());
    }
  }

  _restoreFromStore() {
    const themeId = this._store.get("themeId");
    if (themeId) {
      this.themeId = parseInt(themeId, 10) || null;
    }

    const themeName = this._store.get("themeName");
    if (themeName && themeName !== "null") {
      this.themeName = themeName;
    }

    const lightSchemeId = this._store.get("lightSchemeId");
    if (lightSchemeId) {
      this.lightSchemeId = parseInt(lightSchemeId, 10) || null;
    }

    const darkSchemeId = this._store.get("darkSchemeId");
    if (darkSchemeId) {
      this.darkSchemeId = parseInt(darkSchemeId, 10) || null;
    }

    const lightColors = this._store.getObject("lightColors");
    if (lightColors) {
      this.lightColors = lightColors;
    }

    const darkColors = this._store.getObject("darkColors");
    if (darkColors) {
      this.darkColors = darkColors;
    }

    const customScss = this._store.get("customScss");
    if (customScss && customScss !== "null") {
      this.customScss = customScss;
    }

    const colorDefinitionsScss = this._store.get("colorDefinitionsScss");
    if (colorDefinitionsScss && colorDefinitionsScss !== "null") {
      this.colorDefinitionsScss = colorDefinitionsScss;
    }
  }

  _clearStore() {
    this._store.remove("themeId");
    this._store.remove("themeName");
    this._store.remove("lightSchemeId");
    this._store.remove("darkSchemeId");
    this._store.remove("lightColors");
    this._store.remove("darkColors");
    this._store.remove("customScss");
    this._store.remove("colorDefinitionsScss");
  }
}
