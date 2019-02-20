import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import { THEMES, COMPONENTS } from "admin/models/theme";

const MIN_NAME_LENGTH = 4;

// TODO: use a central repository for themes/components
const POPULAR_THEMES = [
  {
    name: "Graceful",
    value: "https://github.com/discourse/graceful",
    preview: "https://theme-creator.discourse.org/theme/awesomerobot/graceful",
    description: "A light and graceful theme for Discourse.",
    meta_url:
      "https://meta.discourse.org/t/a-graceful-theme-for-discourse/93040"
  },
  {
    name: "Material Design Theme",
    value: "https://github.com/discourse/material-design-stock-theme",
    preview: "https://newmaterial.trydiscourse.com",
    description:
      "Inspired by Material Design, this theme comes with several color palettes (incl. a dark one).",
    meta_url: "https://meta.discourse.org/t/material-design-stock-theme/47142"
  },
  {
    name: "Minima",
    value: "https://github.com/discourse/minima",
    preview: "https://theme-creator.discourse.org/theme/awesomerobot/minima",
    description: "A minimal theme with reduced UI elements and focus on text.",
    meta_url:
      "https://meta.discourse.org/t/minima-a-minimal-theme-for-discourse/108178"
  },
  {
    name: "Sam's Simple Theme",
    value: "https://github.com/discourse/discourse-simple-theme",
    preview: "https://theme-creator.discourse.org/theme/sam/simple",
    description:
      "Simplified front page design with classic colors and typography.",
    meta_url:
      "https://meta.discourse.org/t/sams-personal-minimal-topic-list-design/23552"
  },
  {
    name: "Vincent",
    value: "https://github.com/discourse/discourse-vincent-theme",
    preview: "https://theme-creator.discourse.org/theme/awesomerobot/vincent",
    description: "An elegant dark theme with a few color palettes.",
    meta_url: "https://meta.discourse.org/t/discourse-vincent-theme/76662"
  },
  {
    name: "Alternative Logos",
    value: "https://github.com/discourse/discourse-alt-logo",
    description: "Add alternative logos for dark / light themes.",
    meta_url:
      "https://meta.discourse.org/t/alternative-logo-for-dark-themes/88502",
    component: true
  },
  {
    name: "Brand Header Theme Component",
    value: "https://github.com/discourse/discourse-brand-header",
    description:
      "Add an extra top header with your logo, navigation links and social icons.",
    meta_url: "https://meta.discourse.org/t/brand-header-theme-component/77977",
    component: true
  },
  {
    name: "Custom Header Links",
    value: "https://github.com/discourse/discourse-custom-header-links",
    preview:
      "https://theme-creator.discourse.org/theme/Johani/custom-header-links",
    description: "Easily add custom text-based links to the header.",
    meta_url: "https://meta.discourse.org/t/custom-header-links/90588",
    component: true
  },
  {
    name: "Category Banners",
    value: "https://github.com/discourse/discourse-category-banners",
    preview:
      "https://theme-creator.discourse.org/theme/awesomerobot/discourse-category-banners",
    description:
      "Show banners on category pages using your existing category details.",
    meta_url: "https://meta.discourse.org/t/discourse-category-banners/86241",
    component: true
  },
  {
    name: "Hamburger Theme Selector",
    value: "https://github.com/discourse/discourse-hamburger-theme-selector",
    description:
      "Displays a theme selector in the hamburger menu provided there is more than one user-selectable theme.",
    meta_url: "https://meta.discourse.org/t/hamburger-theme-selector/61210",
    component: true
  },
  {
    name: "Header submenus",
    value: "https://github.com/discourse/discourse-header-submenus",
    preview: "https://theme-creator.discourse.org/theme/Johani/header-submenus",
    description: "Lets you build a header menu with submenus (dropdowns).",
    meta_url: "https://meta.discourse.org/t/header-submenus/94584",
    component: true
  }
];

export default Ember.Controller.extend(ModalFunctionality, {
  popular: Ember.computed.equal("selection", "popular"),
  local: Ember.computed.equal("selection", "local"),
  remote: Ember.computed.equal("selection", "remote"),
  create: Ember.computed.equal("selection", "create"),
  selection: "popular",
  adminCustomizeThemes: Ember.inject.controller(),
  loading: false,
  keyGenUrl: "/admin/themes/generate_key_pair",
  importUrl: "/admin/themes/import",
  checkPrivate: Ember.computed.match("uploadUrl", /^git/),
  localFile: null,
  uploadUrl: null,
  urlPlaceholder: "https://github.com/discourse/sample_theme",
  advancedVisible: false,
  themesController: Ember.inject.controller("adminCustomizeThemes"),
  createTypes: [
    { name: I18n.t("admin.customize.theme.theme"), value: THEMES },
    { name: I18n.t("admin.customize.theme.component"), value: COMPONENTS }
  ],
  selectedType: Ember.computed.alias("themesController.currentTab"),
  component: Ember.computed.equal("selectedType", COMPONENTS),

  @computed("themesController.installedThemes")
  themes(installedThemes) {
    return POPULAR_THEMES.map(t => {
      if (installedThemes.includes(t.name)) {
        Ember.set(t, "installed", true);
      }
      return t;
    });
  },

  @computed(
    "loading",
    "remote",
    "uploadUrl",
    "local",
    "localFile",
    "create",
    "nameTooShort"
  )
  installDisabled(
    isLoading,
    isRemote,
    uploadUrl,
    isLocal,
    localFile,
    isCreate,
    nameTooShort
  ) {
    return (
      isLoading ||
      (isRemote && !uploadUrl) ||
      (isLocal && !localFile) ||
      (isCreate && nameTooShort)
    );
  },

  @observes("privateChecked")
  privateWasChecked() {
    this.get("privateChecked")
      ? this.set("urlPlaceholder", "git@github.com:discourse/sample_theme.git")
      : this.set("urlPlaceholder", "https://github.com/discourse/sample_theme");

    const checked = this.get("privateChecked");
    if (checked && !this._keyLoading) {
      this._keyLoading = true;
      ajax(this.get("keyGenUrl"), { method: "POST" })
        .then(pair => {
          this.setProperties({ privateKey: pair.private_key, publicKey: pair.public_key });
        })
        .catch(popupAjaxError)
        .finally(() => {
          this._keyLoading = false;
        });
    }
  },

  @computed("name")
  nameTooShort(name) {
    return !name || name.length < MIN_NAME_LENGTH;
  },

  @computed("component")
  placeholder(component) {
    if (component) {
      return I18n.t("admin.customize.theme.component_name");
    } else {
      return I18n.t("admin.customize.theme.theme_name");
    }
  },

  @computed("selection")
  submitLabel(selection) {
    return `admin.customize.theme.${
      selection === "create" ? "create" : "install"
    }`;
  },

  @computed("privateChecked", "checkPrivate", "publicKey")
  showPublicKey(privateChecked, checkPrivate, publicKey) {
    return privateChecked && checkPrivate && publicKey;
  },

  actions: {
    uploadLocaleFile() {
      this.set("localFile", $("#file-input")[0].files[0]);
    },

    toggleAdvanced() {
      this.toggleProperty("advancedVisible");
    },

    installThemeFromList(url) {
      this.set("uploadUrl", url);
      this.send("installTheme");
    },

    installTheme() {
      if (this.get("create")) {
        this.set("loading", true);
        const theme = this.store.createRecord("theme");
        theme
          .save({ name: this.get("name"), component: this.get("component") })
          .then(() => {
            this.get("themesController").send("addTheme", theme);
            this.send("closeModal");
          })
          .catch(popupAjaxError)
          .finally(() => this.set("loading", false));

        return;
      }

      let options = {
        type: "POST"
      };

      if (this.get("local")) {
        options.processData = false;
        options.contentType = false;
        options.data = new FormData();
        options.data.append("theme", this.get("localFile"));
      }

      if (this.get("remote") || this.get("popular")) {
        options.data = {
          remote: this.get("uploadUrl"),
          branch: this.get("branch")
        };

        if (this.get("privateChecked")) {
          options.data.private_key = this.get("privateKey");
        }
      }

      if (this.get("model.user_id")) {
        // Used by theme-creator
        options.data["user_id"] = this.get("model.user_id");
      }

      this.set("loading", true);
      ajax(this.get("importUrl"), options)
        .then(result => {
          const theme = this.store.createRecord("theme", result.theme);
          this.get("adminCustomizeThemes").send("addTheme", theme);
          this.send("closeModal");
        })
        .then(() => {
          this.setProperties({ privateKey: null, publicKey: null });
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    }
  }
});
