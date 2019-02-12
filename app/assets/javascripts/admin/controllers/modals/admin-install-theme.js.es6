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
    value: "https://github.com/awesomerobot/graceful",
    preview: "https://theme-creator.discourse.org/theme/awesomerobot/graceful",
    meta_url:
      "https://meta.discourse.org/t/a-graceful-theme-for-discourse/93040"
  },
  {
    name: "Material Design Theme",
    value: "https://github.com/discourse/material-design-stock-theme",
    preview: "https://newmaterial.trydiscourse.com",
    meta_url: "https://meta.discourse.org/t/material-design-stock-theme/47142"
  },
  {
    name: "Minima",
    value: "https://github.com/awesomerobot/minima",
    preview: "https://theme-creator.discourse.org/theme/awesomerobot/minima",
    meta_url:
      "https://meta.discourse.org/t/minima-a-minimal-theme-for-discourse/108178"
  },
  {
    name: "Sam's Simple Theme",
    value: "https://github.com/SamSaffron/discourse-simple-theme",
    preview: "https://theme-creator.discourse.org/theme/sam/simple",
    meta_url:
      "https://meta.discourse.org/t/sams-personal-minimal-topic-list-design/23552"
  },
  {
    name: "Vincent",
    value: "https://github.com/hnb-ku/discourse-vincent-theme",
    preview: "https://theme-creator.discourse.org/theme/awesomerobot/vincent",
    meta_url: "https://meta.discourse.org/t/discourse-vincent-theme/76662"
  },
  {
    name: "Alternative Logos",
    value: "https://github.com/hnb-ku/discourse-alt-logo",
    meta_url:
      "https://meta.discourse.org/t/alternative-logo-for-dark-themes/88502",
    component: true
  },
  {
    name: "Brand Header Theme Component",
    value: "https://github.com/discourse/discourse-brand-header",
    meta_url: "https://meta.discourse.org/t/brand-header-theme-component/77977",
    component: true
  },
  {
    name: "Custom Header Links",
    value: "https://github.com/hnb-ku/discourse-custom-header-links",
    preview:
      "https://theme-creator.discourse.org/theme/Johani/custom-header-links",
    meta_url: "https://meta.discourse.org/t/custom-header-links/90588",
    component: true
  },
  {
    name: "Category Banners",
    value: "https://github.com/awesomerobot/discourse-category-banners",
    preview:
      "https://theme-creator.discourse.org/theme/awesomerobot/discourse-category-banners",
    meta_url: "https://meta.discourse.org/t/discourse-category-banners/86241",
    component: true
  },
  {
    name: "Hamburger Theme Selector",
    value: "https://github.com/discourse/discourse-hamburger-theme-selector",
    meta_url: "https://meta.discourse.org/t/hamburger-theme-selector/61210",
    component: true
  },
  {
    name: "Header submenus",
    value: "https://github.com/hnb-ku/discourse-header-submenus",
    preview: "https://theme-creator.discourse.org/theme/Johani/header-submenus",
    meta_url: "https://meta.discourse.org/t/header-submenus/94584",
    component: true
  }
];

const POPULAR_COMPONENTS = [];

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

  @computed("themesController.installedThemes")
  themes(installedThemes) {
    return POPULAR_THEMES.map(t => {
      if (installedThemes.includes(t.name)) {
        Ember.set(t, "installed", true);
      }
      return t;
    });
  },

  @computed("themesController.installedThemes")
  popularComponents(installedThemes) {
    return POPULAR_COMPONENTS.map(t => {
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
          this.set("privateKey", pair.private_key);
          this.set("publicKey", pair.public_key);
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

  @computed("themesController.currentTab")
  selectedType(tab) {
    return tab;
  },

  @computed("selectedType")
  component(type) {
    return type === COMPONENTS;
  },

  @computed("selection")
  submitLabel(selection) {
    if (selection === "create") return "admin.customize.theme.create";
    else return "admin.customize.theme.install";
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
          this.set("privateKey", null);
          this.set("publicKey", null);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    }
  }
});
