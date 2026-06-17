import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed, getProperties } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { registeredEditCategoryTabs } from "discourse/lib/edit-category-tabs";
import getURL from "discourse/lib/get-url";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import DiscourseURL from "discourse/lib/url";
import { defaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

const SIMPLIFIED_FIELD_LIST = [
  "name",
  "slug",
  "parent_category_id",
  "description",
  "color",
  "text_color",
  "style_type",
  "emoji",
  "icon",
  "locale",
  "localizations",
  "position",
  "num_featured_topics",
  "search_priority",
  "allow_badges",
  "topic_featured_link_allowed",
  "navigate_to_first_post_after_read",
  "all_topics_wiki",
  "allow_unlimited_owner_edits_on_first_post",
  "moderating_group_ids",
  "topic_posting_review_group_ids",
  "reply_posting_review_group_ids",
  "auto_close_hours",
  "auto_close_based_on_last_post",
  "default_view",
  "default_top_period",
  "sort_order",
  "sort_ascending",
  "default_list_filter",
  "show_subcategory_list",
  "subcategory_list_style",
  "read_only_banner",
  "email_in",
  "email_in_enabled",
  "email_in_allow_strangers",
  "mailinglist_mirror",
  "allowed_tag_groups",
  "allowed_tags",
  "required_tag_groups",
  "minimum_required_tags",
  "allow_global_tags",
  "default_slow_mode_seconds",
  "topic_template",
  "topic_title_placeholder",
  "form_template_ids",
  "uploaded_logo",
  "uploaded_logo_dark",
  "uploaded_background",
  "uploaded_background_dark",
];

const SHOW_ADVANCED_TABS_KEY = "category_edit_show_advanced_tabs";
const DISCUSSION_TYPE_ID = "discussion";

export default class EditCategoryTabsController extends Controller {
  @service currentUser;
  @service dialog;
  @service site;
  @service siteSettings;
  @service router;
  @service keyValueStore;
  @service toasts;

  @tracked breadcrumbCategories = this.site.get("categoriesList");
  @tracked
  showAdvancedTabs =
    this.keyValueStore.getItem(SHOW_ADVANCED_TABS_KEY) === "true";
  @tracked formData;
  @tracked selectedTab = "general";
  @tracked formApi = null;
  @tracked siteTextsLocale = this.siteSettings.default_locale;
  @tracked isLoadingSiteTextsLocale = false;
  @tracked siteTextEdits = {};
  @tracked siteTextOriginals = {};
  @autoTrackedArray panels = [];
  saving = false;
  deleting = false;
  showTooltip = false;
  createdCategory = false;
  expandedMenu = false;
  parentParams = null;
  validators = [];
  textColors = ["000000", "FFFFFF"];

  /**
   * Callbacks registered by tab components that are invoked when the form
   * is reset, allowing child components to clean up their own state.
   * @type {Function[]}
   */
  afterResetCallbacks = [];

  @computed("showTooltip", "model.cannot_delete_reason")
  get showDeleteReason() {
    return this.showTooltip && this.model?.cannot_delete_reason;
  }

  @action
  initFormData() {
    const data = getProperties(this.model, ...SIMPLIFIED_FIELD_LIST);

    if (this.siteSettings.content_localization_enabled && !data.locale) {
      data.locale = this.siteSettings.default_locale;
    }

    if (!this.model.styleType) {
      data.style_type = "icon";
    }

    data.required_tag_groups = Array.from(
      data.required_tag_groups ?? [],
      (rtg) => ({
        ...rtg,
      })
    );
    data.category_setting = { ...(this.model.category_setting ?? {}) };
    data.custom_fields = { ...(this.model.custom_fields ?? {}) };

    data.category_type_site_settings = {};
    data.category_type_settings = {
      ...(this.model.category_type_settings ?? {}),
    };
    data.site_texts = {};
    data.category_types = Object.keys(this.model.categoryTypes ?? {});

    if (!data.category_types.includes(DISCUSSION_TYPE_ID)) {
      data.category_types.unshift(DISCUSSION_TYPE_ID);
    }

    Object.values(this.model.categoryTypes ?? {}).forEach((categoryType) => {
      categoryType.configuration_schema.category_custom_fields?.forEach(
        (field) => {
          data.custom_fields[field.key] ??= field.default;
        }
      );

      categoryType.configuration_schema.category_settings?.forEach((field) => {
        data.category_type_settings[field.key] ??= field.default;
      });

      categoryType.configuration_schema.site_settings?.forEach((setting) => {
        data.category_type_site_settings[setting.key] = this.model.id
          ? setting.current
          : setting.default;
      });

      // Site texts are translation overrides, not stored on the category. The
      // server provides the current value (default locale) so we can seed the
      // field without an extra request, then diff against it on save. Keyed by
      // the dot-free form name (the i18n key itself is not FormKit-safe).
      categoryType.configuration_schema.site_texts?.forEach((text) => {
        data.site_texts[text.name] = text.current ?? "";
      });
    });

    // Customizable text is always seeded with the default locale's value, so
    // reset the editing language to match whenever the form is (re)initialized.
    const defaultLocale = this.siteSettings.default_locale;
    this.siteTextsLocale = defaultLocale;
    this.siteTextOriginals = { [defaultLocale]: { ...data.site_texts } };
    this.siteTextEdits = { [defaultLocale]: { ...data.site_texts } };
    this.formData = data;
  }

  get availableLocales() {
    return this.siteSettings.available_locales;
  }

  @computed("saving", "deleting")
  get deleteDisabled() {
    return this.deleting || this.saving || false;
  }

  @computed("name")
  get categoryName() {
    const name = this.name || "";
    return name.trim().length > 0 ? name : i18n("preview");
  }

  @computed("saving", "model.id")
  get saveLabel() {
    if (this.saving) {
      return "saving";
    }
    return this.model?.id ? "category.save" : "category.create_category";
  }

  get baseTitle() {
    if (this.model.id) {
      return i18n("category.edit_dialog_title", {
        categoryName: this.model.name,
      });
    }

    const types = Object.values(this.model.categoryTypes ?? {});
    if (types.length > 0) {
      return i18n("category.create_with_type", {
        typeName: types[0].title,
      });
    }

    return i18n("category.create");
  }

  get isFormDirty() {
    return (this.formApi?.isDirty ?? false) || this.hasPendingSiteTextChanges;
  }

  // True when any locale (visible or stashed) has customizable text that
  // differs from its saved value. The form's own dirty flag only reflects the
  // locale currently on screen, so we track the rest ourselves.
  get hasPendingSiteTextChanges() {
    const entries = this._siteTextEntries;
    if (entries.length === 0) {
      return false;
    }

    const edits = {
      ...this.siteTextEdits,
      [this.siteTextsLocale]: this._visibleSiteTexts,
    };

    return Object.entries(edits).some(([locale, values]) => {
      const originals = this.siteTextOriginals[locale] ?? {};
      return entries.some(
        (entry) => (values[entry.name] ?? "") !== (originals[entry.name] ?? "")
      );
    });
  }

  get _visibleSiteTexts() {
    return this.formApi?.get("site_texts") ?? {};
  }

  @action
  onRegisterFormApi(api) {
    this.formApi = api;
  }

  @action
  setSelectedTab(tab) {
    if (tab !== "general") {
      this.showAdvancedTabs = true;
    }

    if (this.selectedTab === tab) {
      return;
    }

    this.selectedTab = tab;
  }

  /**
   * Runs all registered validators, then performs built-in validation for
   * required fields (name, emoji, icon) when submitting from a non-general tab.
   * Both `addError` and `removeError` are passed to validators so they can
   * manage errors bidirectionally.
   *
   * @param {Object} data - The current form draft data.
   * @param {Object} helpers
   * @param {Function} helpers.addError - Adds a validation error for a field.
   * @param {Function} helpers.removeError - Removes a validation error for a field.
   */
  @action
  validateForm(data, { addError, removeError }) {
    for (const validator of this.validators) {
      validator(data, { addError, removeError });
    }

    if (this.selectedTab === "general") {
      return;
    }

    let hasGeneralTabErrors = false;

    if (!data.name) {
      hasGeneralTabErrors = true;
      addError("name", {
        title: i18n("category.name"),
        message: i18n("form_kit.errors.required"),
      });
    }

    if (data.style_type === "emoji" && !data.emoji) {
      hasGeneralTabErrors = true;
      addError("emoji", {
        title: i18n("category.emoji"),
        message: i18n("category.validations.emoji_required"),
      });
    }

    if (data.style_type === "icon" && !data.icon) {
      hasGeneralTabErrors = true;
      addError("icon", {
        title: i18n("category.icon"),
        message: i18n("category.validations.icon_required"),
      });
    }

    if (hasGeneralTabErrors) {
      this.selectedTab = "general";
    }
  }

  @action
  registerValidator(validator) {
    this.validators.push(validator);
  }

  /**
   * Registers a callback that will be invoked when the form is reset.
   * Tab components use this to synchronize their internal state (e.g.,
   * clearing local selections) when the user resets the form.
   *
   * @param {Function} callback - The function to call on form reset.
   */
  @action
  registerAfterReset(callback) {
    this.afterResetCallbacks.push(callback);
  }

  /**
   * Called by FormKit's `@onReset` hook. Invokes all registered
   * after-reset callbacks so tab components can react to the reset.
   */
  @action
  onFormReset() {
    this.afterResetCallbacks.forEach((callback) => callback());

    const restored = {};
    for (const [locale, values] of Object.entries(this.siteTextOriginals)) {
      restored[locale] = { ...values };
    }
    this.siteTextEdits = restored;

    const current = this.siteTextOriginals[this.siteTextsLocale] ?? {};
    this._siteTextEntries.forEach((entry) => {
      this.formApi?.set(`site_texts.${entry.name}`, current[entry.name] ?? "");
    });
    this.formApi?.commitField("site_texts");
  }

  @action
  isLeavingForm(transition) {
    const name = transition.targetName;
    return (
      !name.startsWith("editCategory.tabs") &&
      !name.startsWith("newCategory.tabs")
    );
  }

  _wouldLoseAccess(category = this.model) {
    if (this.currentUser.admin) {
      return false;
    }

    const permissions = category.permissions;
    if (!permissions?.length) {
      return false;
    }

    const userGroupIds = new Set(this.currentUser.groups.map((g) => g.id));

    return !permissions.some(
      (p) =>
        p.group_id === AUTO_GROUPS.everyone.id || userGroupIds.has(p.group_id)
    );
  }

  @action
  async saveCategory(data) {
    if (this.validators.some((validator) => validator())) {
      return;
    }

    // eslint-disable-next-line no-unused-vars
    const { visibility, ...categoryData } = data;
    this.model.setProperties(categoryData);

    // If permissions is empty or not set, ensure it's an empty array (public category)
    if (!this.model.permissions || this.model.permissions.length === 0) {
      this.model.set("permissions", []);
    }

    const lostAccess = this._wouldLoseAccess();

    if (lostAccess) {
      const confirmed = await this.dialog.yesNoConfirm({
        message: i18n("category.errors.self_lockout"),
      });

      if (!confirmed) {
        return;
      }
    }

    this.set("saving", true);

    try {
      const previousTypes = new Set(
        Object.keys(this.model.categoryTypes ?? {})
      );
      const result = await this.model.save();
      const siteTextsChanged = await this._saveSiteTexts();
      const updatedModel = this.site.updateCategory(result.category);
      updatedModel.setupGroupsAndPermissions();

      if (lostAccess) {
        this.router.transitionTo(`discovery.${defaultHomepage()}`);
        return;
      }

      const newTypes = Object.keys(result.category.category_types ?? {});
      const typeWasAdded = newTypes.some((t) => !previousTypes.has(t));
      // A reload is needed when site texts change
      if (typeWasAdded || siteTextsChanged) {
        if (this.model.id) {
          window.location.reload();
        } else {
          window.location = this.router.urlFor(
            "editCategory",
            Category.slugFor(updatedModel)
          );
        }
        return;
      }

      this.set("saving", false);
      this.initFormData();

      this.toasts.success({
        duration: "short",
        data: { message: i18n("saved") },
      });

      if (!this.model.id) {
        this.router.transitionTo(
          "editCategory",
          Category.slugFor(updatedModel)
        );
      }

      // ensure breadcrumbs contain the updated category model
      this.breadcrumbCategories = this.site.categoriesList.map((c) =>
        c.id === this.model.id ? updatedModel : c
      );
    } catch (error) {
      this.set("saving", false);
      popupAjaxError(error);
      this.model.set("parent_category_id", undefined);
    }
  }

  @action
  async switchSiteTextsLocale(locale) {
    if (locale === this.siteTextsLocale) {
      return;
    }

    this._stashVisibleSiteTexts();

    this.isLoadingSiteTextsLocale = true;
    const previousLocale = this.siteTextsLocale;
    this.siteTextsLocale = locale;

    try {
      let values = this.siteTextEdits[locale];
      if (!values) {
        values = await this._fetchSiteTexts(locale);
        this.siteTextOriginals = {
          ...this.siteTextOriginals,
          [locale]: { ...values },
        };
        this.siteTextEdits = { ...this.siteTextEdits, [locale]: { ...values } };
      }

      this._siteTextEntries.forEach((entry) => {
        this.formApi?.set(`site_texts.${entry.name}`, values[entry.name] ?? "");
      });
      this.formApi?.commitField("site_texts");
    } catch (error) {
      this.siteTextsLocale = previousLocale;
      popupAjaxError(error);
    } finally {
      this.isLoadingSiteTextsLocale = false;
    }
  }

  _stashVisibleSiteTexts() {
    this.siteTextEdits = {
      ...this.siteTextEdits,
      [this.siteTextsLocale]: { ...this._visibleSiteTexts },
    };
  }

  async _fetchSiteTexts(locale) {
    const entries = this._siteTextEntries;
    const responses = await Promise.all(
      entries.map((entry) =>
        ajax(
          `/admin/customize/site_texts/${encodeURIComponent(entry.key)}.json`,
          { data: { locale } }
        ).catch(() => ({ site_text: { value: "" } }))
      )
    );

    const values = {};
    entries.forEach((entry, index) => {
      values[entry.name] = responses[index].site_text?.value ?? "";
    });
    return values;
  }

  async _saveSiteTexts() {
    this._stashVisibleSiteTexts();

    const entries = this._siteTextEntries;
    let changed = false;

    for (const [locale, values] of Object.entries(this.siteTextEdits)) {
      const originals = this.siteTextOriginals[locale] ?? {};

      for (const entry of entries) {
        const newValue = values[entry.name] ?? "";
        if (newValue === (originals[entry.name] ?? "")) {
          continue;
        }

        const url = `/admin/customize/site_texts/${encodeURIComponent(
          entry.key
        )}?locale=${encodeURIComponent(locale)}`;
        if (newValue.trim() === "") {
          await ajax(url, { type: "DELETE" });
        } else {
          await ajax(url, {
            type: "PUT",
            data: { site_text: { value: newValue, locale } },
          });
        }
        changed = true;
      }
    }

    return changed;
  }

  get _siteTextEntries() {
    const entries = [];
    Object.values(this.model?.categoryTypes ?? {}).forEach((categoryType) => {
      categoryType.configuration_schema.site_texts?.forEach((entry) =>
        entries.push(entry)
      );
    });
    return entries;
  }

  @action
  deleteCategory() {
    if (this.deleteDisabled) {
      return;
    }

    this.set("deleting", true);
    this.dialog.deleteConfirm({
      title: i18n("category.delete_confirm"),
      didConfirm: () => {
        this.model
          .destroy()
          .then(() => {
            this.router.transitionTo("discovery.categories");
          })
          .catch(() => {
            this.displayErrors([i18n("category.delete_error")]);
          })
          .finally(() => {
            this.set("deleting", false);
          });
      },
      didCancel: () => this.set("deleting", false),
    });
  }

  @action
  toggleDeleteTooltip() {
    if (this.deleteDisabled) {
      return;
    }

    this.toggleProperty("showTooltip");
  }

  @action
  goBack() {
    DiscourseURL.routeTo(this.model.url);
  }

  @action
  toggleAdvancedTabs() {
    this.showAdvancedTabs = !this.showAdvancedTabs;

    // Save preference to localStorage
    this.keyValueStore.setItem(
      SHOW_ADVANCED_TABS_KEY,
      this.showAdvancedTabs.toString()
    );

    // When collapsing, reset to general unless current tab is still visible
    if (!this.showAdvancedTabs && this.selectedTab !== "general") {
      const primaryTab = registeredEditCategoryTabs.find(
        (tab) => tab.id === this.selectedTab && tab.primary
      );
      if (!primaryTab) {
        next(() => {
          this.selectedTab = "general";
          if (this.router.currentRouteName?.startsWith("newCategory")) {
            DiscourseURL.routeTo(getURL("/new-category/general"));
          } else if (this.parentParams?.slug) {
            DiscourseURL.routeTo(
              getURL(`/c/${this.parentParams.slug}/edit/general`)
            );
          }
        });
      }
    }
  }
}
