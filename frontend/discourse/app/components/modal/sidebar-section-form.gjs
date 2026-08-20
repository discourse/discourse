/* eslint-disable ember/no-classic-components */
import { cached, tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { fn, uniqueId } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import SectionFormLink from "discourse/components/sidebar/section-form-link";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import {
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import { SIDEBAR_SECTION, SIDEBAR_URL } from "discourse/lib/constants";
import { afterRender, bind } from "discourse/lib/decorators";
import { isSameLocale } from "discourse/lib/locale-normalizer";
import { sanitize } from "discourse/lib/text";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";
import DSelect from "discourse/ui-kit/d-select";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

class Section {
  @tracked title;
  @tracked public;
  @tracked locale;
  @autoTrackedArray links;
  @autoTrackedArray secondaryLinks;
  @autoTrackedArray localizations;

  constructor({
    title,
    links,
    secondaryLinks,
    id,
    publicSection,
    sectionType,
    hideTitleInput,
    localizations,
    locale,
  }) {
    this.title = title;
    this.public = publicSection;
    this.sectionType = sectionType;
    this.links = links;
    this.secondaryLinks = secondaryLinks;
    this.id = id;
    this.hideTitleInput = hideTitleInput;
    this.localizations = localizations || [];
    this.locale = locale;
  }

  get valid() {
    const allLinks = this.links
      .filter((link) => !link._destroy)
      .concat(this.secondaryLinks?.filter((link) => !link._destroy) || []);
    const validLinks =
      allLinks.length > 0 &&
      allLinks.every((link) => (this.public ? link.valid : link.validSource));
    const validLocalizations =
      !this.public ||
      this.localizations
        .filter((localization) => !localization._destroy)
        .every((localization) => localization.valid);
    return this.validTitle && validLinks && validLocalizations;
  }

  get customSection() {
    return !this.sectionType;
  }

  get communitySection() {
    return this.sectionType === "community";
  }

  get validTitle() {
    return !this.#blankTitle && !this.#tooLongTitle;
  }

  get invalidTitleMessage() {
    if (this.title === undefined) {
      return;
    }
    if (this.#blankTitle) {
      return i18n("sidebar.sections.custom.title.validation.blank");
    }
    if (this.#tooLongTitle) {
      return i18n("sidebar.sections.custom.title.validation.maximum", {
        count: SIDEBAR_SECTION.max_title_length,
      });
    }
  }

  get titleCssClass() {
    return this.title === undefined || this.validTitle ? "" : "warning";
  }

  get #blankTitle() {
    return isEmpty(this.title);
  }

  get #tooLongTitle() {
    return this.title.length > SIDEBAR_SECTION.max_title_length;
  }
}

class Localization {
  @tracked locale;
  @tracked value;
  @tracked _destroy;

  constructor({ id, locale, ...rest } = {}) {
    this.id = id;
    this.locale = locale;
    this.value = rest[this.constructor.key];
  }

  get translated() {
    return !isEmpty(this.value);
  }

  get valid() {
    return !isEmpty(this.locale) && !this.#tooLong;
  }

  get invalidMessage() {
    if (this.#tooLong) {
      return i18n(this.constructor.tooLongKey, {
        count: this.constructor.maxLength,
      });
    }
  }

  get #tooLong() {
    return this.value?.length > this.constructor.maxLength;
  }
}

class SectionLocalization extends Localization {
  static key = "title";
  static maxLength = SIDEBAR_SECTION.max_title_length;
  static tooLongKey = "sidebar.sections.custom.title.validation.maximum";
}

class LinkLocalization extends Localization {
  static key = "name";
  static maxLength = SIDEBAR_URL.max_name_length;
  static tooLongKey = "sidebar.sections.custom.links.name.validation.maximum";
}

class SectionLink {
  @tracked icon;
  @tracked name;
  @tracked value;
  @tracked locale;
  // Reassigned when a link moves between segments; tracked so a future reader
  // of it, or of `isPrimary`, observes the move during render.
  @tracked segment;
  @autoTrackedArray localizations;
  @tracked _destroy;

  constructor({
    router,
    icon: iconName,
    name,
    value,
    id,
    objectId,
    segment,
    localizations,
    locale,
    canLocalize = true,
  }) {
    this.router = router;
    this.icon = iconName || "link";
    this.name = name;
    this.value = value;
    this.id = id;
    this.httpHost = "http://" + window.location.host;
    this.httpsHost = "https://" + window.location.host;
    this.objectId = objectId;
    this.segment = segment;
    this.localizations = localizations || [];
    this.locale = locale;
    this.canLocalize = canLocalize;
  }

  get path() {
    return this.value?.replace(this.httpHost, "").replace(this.httpsHost, "");
  }

  get valid() {
    const validLocalizations = this.localizations
      .filter((localization) => !localization._destroy)
      .every((localization) => localization.valid);
    return this.validSource && validLocalizations;
  }

  get validSource() {
    return this.validIcon && this.validName && this.validValue;
  }

  get validIcon() {
    return !this.#blankIcon && !this.#tooLongIcon;
  }

  get validName() {
    return !this.#blankName && !this.#tooLongName;
  }

  get validValue() {
    return !this.#blankValue && !this.#tooLongValue && !this.#invalidValue;
  }

  get invalidIconMessage() {
    if (this.#blankIcon) {
      return i18n("sidebar.sections.custom.links.icon.validation.blank");
    }
    if (this.#tooLongIcon) {
      return i18n("sidebar.sections.custom.links.icon.validation.maximum", {
        count: SIDEBAR_URL.max_icon_length,
      });
    }
  }

  get invalidNameMessage() {
    if (this.name === undefined) {
      return;
    }
    if (this.#blankName) {
      return i18n("sidebar.sections.custom.links.name.validation.blank");
    }
    if (this.#tooLongName) {
      return i18n("sidebar.sections.custom.links.name.validation.maximum", {
        count: SIDEBAR_URL.max_name_length,
      });
    }
  }

  get invalidValueMessage() {
    if (this.value === undefined) {
      return;
    }
    if (this.#blankValue) {
      return i18n("sidebar.sections.custom.links.value.validation.blank");
    }
    if (this.#tooLongValue) {
      return i18n("sidebar.sections.custom.links.value.validation.maximum", {
        count: SIDEBAR_URL.max_value_length,
      });
    }
    if (this.#invalidValue) {
      return i18n("sidebar.sections.custom.links.value.validation.invalid");
    }
  }

  get iconCssClass() {
    return this.icon === undefined || this.validIcon ? "" : "warning";
  }

  get nameCssClass() {
    return this.name === undefined || this.validName ? "" : "warning";
  }

  get valueCssClass() {
    return this.value === undefined || this.validValue ? "" : "warning";
  }

  get isPrimary() {
    return this.segment === "primary";
  }

  get #blankIcon() {
    return isEmpty(this.icon);
  }

  get #tooLongIcon() {
    return this.icon.length > SIDEBAR_URL.max_icon_length;
  }

  get #blankName() {
    return isEmpty(this.name);
  }

  get #tooLongName() {
    return this.name.length > SIDEBAR_URL.max_name_length;
  }

  get #blankValue() {
    return isEmpty(this.value);
  }

  get #tooLongValue() {
    return this.value.length > SIDEBAR_URL.max_value_length;
  }

  get #invalidValue() {
    return this.path && !this.#validLink();
  }

  #validLink() {
    try {
      return new URL(this.value, document.location.origin);
    } catch {
      return false;
    }
  }
}

const TranslationRow = <template>
  {{#let (uniqueId) as |inputId|}}
    <div class="sidebar-section-translations__row">
      <label class="sidebar-section-translations__source" for={{inputId}}>
        {{@source}}
      </label>

      <Input
        @type="text"
        @value={{@localization.value}}
        id={{inputId}}
        class="sidebar-section-translations__value
          {{unless @localization.translated '--untranslated'}}"
        placeholder={{i18n
          "sidebar.sections.custom.localizations.untranslated"
        }}
        lang={{@localization.locale}}
        {{on "input" (withEventValue (fn (mut @localization.value)))}}
      />

      {{#if @localization.invalidMessage}}
        <div role="alert" aria-live="assertive" class="warning">
          {{@localization.invalidMessage}}
        </div>
      {{/if}}
    </div>
  {{/let}}
</template>;

@tagName("")
export default class SidebarSectionForm extends Component {
  @service dialog;
  @service languageNameLookup;
  @service router;
  @service siteSettings;

  @tracked flash;
  @tracked flashType;
  @tracked showingTranslations = false;

  nextObjectId = 0;
  nextGroupKey = 0;
  groupKeys = new Map();

  /**
   * Applies one normalized move from the reorderable lists onto the backing
   * arrays, which keep links awaiting deletion in place with `_destroy` set.
   * The proposed orders describe only the visible links, so each visible link
   * is re-slotted around the hidden ones, and a cross-list move re-segments
   * the link it carried. Announcements and no-op suppression are the lists'
   * own; only this projection is domain knowledge.
   *
   * @param {Object} move - The normalized move from the list group.
   */
  linkName = (link) => link.name;

  @cached
  get transformedModel() {
    const section = this.model?.section;

    if (section) {
      const sectionLocale = section.locale || this.siteSettings.default_locale;

      return new Section({
        title: section.title,
        publicSection: section.public,
        sectionType: section.section_type,
        links: section.links.reduce((acc, link) => {
          if (link.segment === "primary") {
            this.nextObjectId++;
            acc.push(this.initLink(link, sectionLocale));
          }
          return acc;
        }, []),
        secondaryLinks: section.links.reduce((acc, link) => {
          if (link.segment === "secondary") {
            this.nextObjectId++;
            acc.push(this.initLink(link, sectionLocale));
          }
          return acc;
        }, []),
        id: section.id,
        hideTitleInput: this.model.hideSectionHeader,
        localizations: this.initLocalizations(
          section.localizations,
          SectionLocalization
        ),
        locale: sectionLocale,
      });
    } else {
      return new Section({
        links: [
          new SectionLink({
            router: this.router,
            objectId: this.nextObjectId,
            segment: "primary",
            locale: this.siteSettings.default_locale,
          }),
        ],
        locale: this.siteSettings.default_locale,
      });
    }
  }

  initLink(link, sectionLocale) {
    return new SectionLink({
      router: this.router,
      icon: link.icon,
      name: link.name,
      value: link.value,
      id: link.id,
      objectId: this.nextObjectId,
      segment: link.segment,
      localizations: this.initLocalizations(
        link.localizations,
        LinkLocalization
      ),
      locale: link.locale || sectionLocale,
      canLocalize: link.can_localize ?? link.canLocalize,
    });
  }

  initLocalizations(localizations, klass) {
    return (localizations || []).map((localization) => new klass(localization));
  }

  create() {
    return ajax(`/sidebar_sections`, {
      type: "POST",
      contentType: "application/json",
      dataType: "json",
      data: JSON.stringify({
        title: this.transformedModel.title,
        public: this.transformedModel.public,
        locale: this.serializeSectionSourceLocale(),
        localizations: this.serializeSectionLocalizations(),
        links: this.transformedModel.links.map((link) => {
          return {
            icon: link.icon,
            name: link.name,
            value: link.path,
            locale: this.serializeLinkSourceLocale(link),
            localizations: this.serializeLinkLocalizations(link),
          };
        }),
      }),
    })
      .then((data) => {
        this.currentUser.set(
          "sidebar_sections",
          this.currentUser.sidebar_sections.concat(data.sidebar_section)
        );
        this.closeModal();
      })
      .catch((e) => {
        this.flash = sanitize(extractError(e));
        this.flashType = "error";
      });
  }

  update() {
    return this.wasPublic || this.isPublic
      ? this.#updateWithConfirm()
      : this.#updateCall();
  }

  get clearedTranslationCount() {
    const cleared = (record) =>
      record.localizations.filter(
        (localization) =>
          localization.id && !localization._destroy && !localization.translated
      ).length;

    return (
      (this.showLocalizations ? cleared(this.transformedModel) : 0) +
      this.localizableLinks.reduce((count, link) => count + cleared(link), 0)
    );
  }

  #updateWithConfirm() {
    const messages = [
      this.isPublic
        ? i18n("sidebar.sections.custom.update_public_confirm")
        : i18n("sidebar.sections.custom.mark_as_private_confirm"),
    ];

    if (this.clearedTranslationCount > 0) {
      messages.push(
        i18n("sidebar.sections.custom.localizations.remove_cleared_confirm", {
          count: this.clearedTranslationCount,
        })
      );
    }

    return this.dialog.yesNoConfirm({
      message: messages.join("<br><br>"),
      didConfirm: () => {
        return this.#updateCall();
      },
    });
  }

  #updateCall() {
    return ajax(`/sidebar_sections/${this.transformedModel.id}`, {
      type: "PUT",
      contentType: "application/json",
      dataType: "json",
      data: JSON.stringify({
        title: this.transformedModel.title,
        public: this.transformedModel.public,
        locale: this.serializeSectionSourceLocale(),
        localizations: this.serializeSectionLocalizations(),
        links: this.transformedModel.links
          .concat(this.transformedModel?.secondaryLinks || [])
          .map((link) => {
            return {
              id: link.id,
              icon: link.icon,
              name: link.name,
              value: link.path,
              segment: link.segment,
              _destroy: link._destroy,
              locale: this.serializeLinkSourceLocale(link),
              localizations: this.serializeLinkLocalizations(link),
            };
          }),
      }),
    })
      .then((data) => {
        const newSidebarSections = this.currentUser.sidebar_sections.map(
          (section) => {
            if (section.id === data["sidebar_section"].id) {
              return data["sidebar_section"];
            }
            return section;
          }
        );
        this.currentUser.set("sidebar_sections", newSidebarSections);
        this.closeModal();
      })
      .catch((e) => {
        this.flash = sanitize(extractError(e));
        this.flashType = "error";
      });
  }

  get activeLinks() {
    return this.transformedModel.links.filter((link) => !link._destroy);
  }

  get activeSecondaryLinks() {
    return this.transformedModel.secondaryLinks?.filter(
      (link) => !link._destroy
    );
  }

  @cached
  get activeLocalizations() {
    return this.#activeLocalizations(this.transformedModel);
  }

  get translationsLabel() {
    const count = this.translationLocales.length;

    return count === 0
      ? i18n("sidebar.sections.custom.localizations.add_first")
      : i18n("sidebar.sections.custom.localizations.manage", { count });
  }

  get hasTranslatableLocales() {
    return this.localeOptions.length > 0;
  }

  get showSourceLocale() {
    return this.showLocalizations && this.hasTranslatableLocales;
  }

  get canTranslate() {
    return (
      (this.showLocalizations || this.localizableLinks.length > 0) &&
      this.hasTranslatableLocales
    );
  }

  @cached
  get localizableLinks() {
    if (!this.showLinkLocalizations) {
      return [];
    }

    return this.transformedModel.links
      .concat(this.transformedModel.secondaryLinks || [])
      .filter((link) => !link._destroy && this.canLocalizeLink(link));
  }

  canLocalizeLink(link) {
    return this.transformedModel.customSection || link.canLocalize;
  }

  #activeLocalizations(record) {
    return record.localizations.filter(
      (localization) =>
        !localization._destroy &&
        !isSameLocale(localization.locale, record.locale)
    );
  }

  @cached
  get translationLocales() {
    const locales = [];

    const track = (localizations) =>
      localizations.forEach(({ locale }) => {
        if (locale && !locales.includes(locale)) {
          locales.push(locale);
        }
      });

    if (this.showLocalizations) {
      track(this.activeLocalizations);
    }

    this.localizableLinks.forEach((link) =>
      track(this.#activeLocalizations(link))
    );

    return locales;
  }

  @cached
  get translationGroups() {
    return this.translationLocales.map((locale) => ({
      key: this.#groupKey(locale),
      locale,
      name: this.languageNameLookup.getLanguageName(locale),
      localeOptions: this.#localeOptionsFor(locale),
      sectionLocalization: this.showLocalizations
        ? this.activeLocalizations.find(
            (localization) => localization.locale === locale
          )
        : null,
      links: this.localizableLinks
        .filter((link) => !isSameLocale(link.locale, locale))
        .map((link) => ({
          link,
          localization: this.#activeLocalizations(link).find(
            (localization) => localization.locale === locale
          ),
        })),
    }));
  }

  get nextTranslationLocale() {
    return (
      this.localeOptions.find(
        (locale) => !this.translationLocales.includes(locale.value)
      )?.value || ""
    );
  }

  get missingTranslationCount() {
    return this.translationGroups.reduce(
      (count, group) =>
        count +
        (this.showLocalizations && !group.sectionLocalization?.translated
          ? 1
          : 0) +
        group.links.filter(({ localization }) => !localization?.translated)
          .length,
      0
    );
  }

  get configuredLocales() {
    return (
      this.siteSettings.available_content_localization_locales?.map(
        (locale) => locale.value
      ) ||
      this.siteSettings.content_localization_supported_locales
        ?.split("|")
        .filter(Boolean) ||
      []
    );
  }

  get sourceLocaleOptions() {
    return this.#toLocaleOptions([
      ...this.configuredLocales,
      this.transformedModel.locale,
    ]);
  }

  @cached
  get localeOptions() {
    const locales = new Set(this.configuredLocales);

    this.transformedModel.localizations.forEach((localization) =>
      locales.add(localization.locale)
    );
    this.transformedModel.links
      .concat(this.transformedModel.secondaryLinks || [])
      .forEach((link) =>
        link.localizations.forEach((localization) =>
          locales.add(localization.locale)
        )
      );

    return this.#toLocaleOptions(
      [...locales].filter((locale) => this.#isTranslationTarget(locale))
    );
  }

  #isTranslationTarget(locale) {
    if (
      this.showLocalizations &&
      !isSameLocale(locale, this.transformedModel.locale)
    ) {
      return true;
    }

    return this.localizableLinks.some(
      (link) => !isSameLocale(link.locale, locale)
    );
  }

  #groupKey(locale) {
    if (!this.groupKeys.has(locale)) {
      this.groupKeys.set(locale, `group-${this.nextGroupKey++}`);
    }

    return this.groupKeys.get(locale);
  }

  #localeOptionsFor(locale) {
    const options = this.localeOptions;
    const own = options.some((option) => option.value === locale)
      ? []
      : this.#toLocaleOptions([locale]);

    return [...options, ...own].map((option) => ({
      ...option,
      disabled:
        option.value !== locale &&
        this.translationLocales.includes(option.value),
    }));
  }

  #toLocaleOptions(locales) {
    return uniqueItemsFromArray(locales.filter(Boolean)).map((locale) => ({
      name: this.languageNameLookup.getLanguageName(locale),
      value: locale,
    }));
  }

  get showLocalizations() {
    return (
      this.currentUser?.admin &&
      this.siteSettings.content_localization_enabled &&
      this.transformedModel.public &&
      this.transformedModel.customSection
    );
  }

  get showLinkLocalizations() {
    return (
      this.currentUser?.admin &&
      this.siteSettings.content_localization_enabled &&
      this.transformedModel.public &&
      (this.transformedModel.customSection ||
        this.transformedModel.communitySection)
    );
  }

  get header() {
    return this.transformedModel.id
      ? "sidebar.sections.custom.edit"
      : "sidebar.sections.custom.add";
  }

  get isPublic() {
    return this.transformedModel.public;
  }

  get wasPublic() {
    return this.model?.section?.public;
  }

  @afterRender
  focusNewRowInput(id) {
    document
      .querySelector(
        `[data-reorderable-key="${id}"] .d-icon-grid-picker-trigger`
      )
      .focus();
  }

  @bind
  handleMove(move) {
    const arrays = {
      primary: this.transformedModel.links,
      secondary: this.transformedModel.secondaryLinks,
    };
    const source = arrays[move.fromList];
    const destination = arrays[move.toList];

    if (move.fromList !== move.toList) {
      removeValueFromArray(source, move.item);
      move.item.segment = move.toList;
      // Anchored on the visible link that follows the landing slot, so links
      // awaiting deletion keep their positions in the stored array.
      const following = move.proposedToItems[move.toIndex + 1];
      const at = following
        ? destination.indexOf(following)
        : destination.length;
      destination.splice(at, 0, move.item);
      return;
    }

    const proposed = [...move.proposedToItems];
    const next = destination.map((link) =>
      link._destroy ? link : proposed.shift()
    );
    destination.splice(0, destination.length, ...next);
  }

  get canDelete() {
    return this.transformedModel.id && !this.transformedModel.sectionType;
  }

  @bind
  deleteLink(link) {
    if (link.id) {
      link._destroy = "1";
    } else {
      const links = link.isPrimary
        ? this.transformedModel.links
        : this.transformedModel.secondaryLinks;

      removeValueFromArray(links, link);
    }
  }

  @action
  showTranslations() {
    this.#syncLocalizationSlots();
    this.showingTranslations = true;
  }

  #syncLocalizationSlots() {
    this.translationGroups
      .map((group) => group.locale)
      .forEach((locale) => this.#addLocalizationSlots(locale));
  }

  @action
  hideTranslations() {
    this.showingTranslations = false;
  }

  @action
  addLanguage() {
    const locale = this.nextTranslationLocale;
    if (!locale) {
      return;
    }

    this.#addLocalizationSlots(locale);
  }

  @action
  removeLanguage(group) {
    const persisted =
      group.sectionLocalization?.id ||
      group.links.some(({ localization }) => localization?.id);

    if (!persisted) {
      this.#removeLocalizationSlots(group.locale);
      return;
    }

    return this.dialog.yesNoConfirm({
      message: i18n(
        "sidebar.sections.custom.localizations.remove_language_confirm",
        { language: group.name }
      ),
      didConfirm: () => this.#removeLocalizationSlots(group.locale),
    });
  }

  @bind
  setGroupLocale(group, locale) {
    if (locale !== group.locale && this.translationLocales.includes(locale)) {
      return;
    }

    this.groupKeys.set(locale, group.key);
    this.groupKeys.delete(group.locale);

    this.#moveLocalization(
      this.transformedModel.localizations,
      group.sectionLocalization,
      locale
    );

    group.links.forEach(({ link, localization }) => {
      if (isSameLocale(link.locale, locale)) {
        return;
      }

      this.#moveLocalization(link.localizations, localization, locale);
    });

    this.#addLocalizationSlots(locale);
  }

  #moveLocalization(localizations, localization, locale) {
    if (!localization || localization.locale === locale) {
      return;
    }

    const occupant = localizations.find(
      (other) => other !== localization && other.locale === locale
    );

    if (!occupant) {
      localization.locale = locale;
      return;
    }

    occupant.value = localization.value;
    occupant._destroy = undefined;
    this.#discardLocalization(localizations, localization);
  }

  #addLocalizationSlots(locale) {
    if (
      this.showLocalizations &&
      !isSameLocale(locale, this.transformedModel.locale) &&
      !this.#reclaimLocalization(this.transformedModel.localizations, locale)
    ) {
      this.transformedModel.localizations.push(
        new SectionLocalization({ locale })
      );
    }

    this.localizableLinks.forEach((link) => {
      if (isSameLocale(link.locale, locale)) {
        return;
      }

      if (!this.#reclaimLocalization(link.localizations, locale)) {
        link.localizations.push(new LinkLocalization({ locale }));
      }
    });
  }

  #reclaimLocalization(localizations, locale) {
    const existing = localizations.find(
      (localization) => localization.locale === locale
    );

    if (existing) {
      existing._destroy = undefined;
    }

    return existing;
  }

  #removeLocalizationSlots(locale) {
    this.groupKeys.delete(locale);

    this.#discardLocalizations(this.transformedModel.localizations, locale);
    this.localizableLinks.forEach((link) =>
      this.#discardLocalizations(link.localizations, locale)
    );
  }

  #discardLocalizations(localizations, locale) {
    localizations
      .filter((localization) => localization.locale === locale)
      .forEach((localization) =>
        this.#discardLocalization(localizations, localization)
      );
  }

  #discardLocalization(localizations, localization) {
    if (localization.id) {
      localization._destroy = "1";
    } else {
      removeValueFromArray(localizations, localization);
    }
  }

  @action
  setSourceLocale(locale) {
    this.transformedModel.locale = locale;
    this.transformedModel.links.forEach((link) => (link.locale = locale));
    this.transformedModel.secondaryLinks?.forEach(
      (link) => (link.locale = locale)
    );
  }

  serializeSectionSourceLocale() {
    return this.showLocalizations ? this.transformedModel.locale : undefined;
  }

  serializeLinkSourceLocale(link) {
    if (!this.showLinkLocalizations || !this.canLocalizeLink(link)) {
      return undefined;
    }

    return link.locale;
  }

  serializeSectionLocalizations() {
    if (!this.showLocalizations) {
      return [];
    }

    return this.#serializeLocalizations(
      this.transformedModel.localizations,
      "title"
    );
  }

  serializeLinkLocalizations(link) {
    if (!this.showLinkLocalizations || !this.canLocalizeLink(link)) {
      return [];
    }

    return this.#serializeLocalizations(link.localizations);
  }

  #serializeLocalizations(localizations) {
    return localizations
      .map((localization) => {
        const { id, locale, _destroy, translated } = localization;

        if (_destroy || !translated) {
          return id ? { id, locale, _destroy: "1" } : null;
        }

        return {
          id,
          locale,
          [localization.constructor.key]: localization.value,
        };
      })
      .filter(Boolean);
  }

  @action
  addLink() {
    this.nextObjectId = this.nextObjectId + 1;
    this.transformedModel.links.push(
      new SectionLink({
        router: this.router,
        objectId: this.nextObjectId,
        segment: "primary",
        locale: this.transformedModel.locale,
        canLocalize: true,
      })
    );

    this.focusNewRowInput(this.nextObjectId);
  }

  @action
  addSecondaryLink() {
    this.nextObjectId = this.nextObjectId + 1;
    this.transformedModel.secondaryLinks.push(
      new SectionLink({
        router: this.router,
        objectId: this.nextObjectId,
        segment: "secondary",
        locale: this.transformedModel.locale,
        canLocalize: true,
      })
    );

    this.focusNewRowInput(this.nextObjectId);
  }

  @action
  resetToDefault() {
    return this.dialog.yesNoConfirm({
      message: i18n("sidebar.sections.custom.reset_confirm"),
      didConfirm: () => {
        return ajax(`/sidebar_sections/reset/${this.transformedModel.id}`, {
          type: "PUT",
        })
          .then((data) => {
            this.currentUser.sidebar_sections.shift();
            this.currentUser.sidebar_sections.unshift(data["sidebar_section"]);
            this.closeModal();
          })
          .catch((e) => {
            this.flash = sanitize(extractError(e));
            this.flashType = "error";
          });
      },
      didCancel: () => {
        this.closeModal();
      },
    });
  }

  @action
  save() {
    this.transformedModel.id ? this.update() : this.create();
  }

  @action
  setPublic(event) {
    this.transformedModel.public = event.target.checked;
  }

  @action
  delete() {
    return this.dialog.deleteConfirm({
      title: this.model.section.public
        ? i18n("sidebar.sections.custom.delete_public_confirm")
        : i18n("sidebar.sections.custom.delete_confirm"),
      didConfirm: () => {
        return ajax(`/sidebar_sections/${this.transformedModel.id}`, {
          type: "DELETE",
        })
          .then(() => {
            const newSidebarSections = this.currentUser.sidebar_sections.filter(
              (section) => {
                return section.id !== this.transformedModel.id;
              }
            );

            this.currentUser.set("sidebar_sections", newSidebarSections);
            this.closeModal();
          })
          .catch((e) => {
            this.flash = sanitize(extractError(e));
            this.flashType = "error";
          });
      },
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @title={{i18n this.header}}
      class="sidebar-section-form-modal --large"
    >
      <:body>
        {{#if this.showingTranslations}}
          <div class="sidebar-section-translations">
            <DButton
              @action={{this.hideTranslations}}
              @icon="chevron-left"
              @label="sidebar.sections.custom.localizations.back"
              class="btn-flat btn-text sidebar-section-translations__back"
            />

            {{#each this.translationGroups key="key" as |group|}}
              <div
                class="sidebar-section-translations__language"
                data-locale={{group.locale}}
              >
                <div class="sidebar-section-translations__language-header">
                  <DSelect
                    @value={{group.locale}}
                    @onChange={{fn this.setGroupLocale group}}
                    @includeNone={{false}}
                    class="sidebar-section-translations__language-select"
                    aria-label={{i18n
                      "sidebar.sections.custom.localizations.locale"
                    }}
                    as |select|
                  >
                    {{#each group.localeOptions key="value" as |locale|}}
                      <select.Option
                        @value={{locale.value}}
                        disabled={{locale.disabled}}
                      >{{locale.name}}</select.Option>
                    {{/each}}
                  </DSelect>

                  <DButton
                    @action={{fn this.removeLanguage group}}
                    @icon="trash-can"
                    @label="sidebar.sections.custom.localizations.remove_language"
                    class="btn-flat btn-text sidebar-section-translations__remove-language"
                  />
                </div>

                {{#if group.sectionLocalization}}
                  <div class="sidebar-section-translations__caption">
                    {{i18n "sidebar.sections.custom.localizations.title_label"}}
                  </div>

                  <TranslationRow
                    @source={{this.transformedModel.title}}
                    @localization={{group.sectionLocalization}}
                  />
                {{/if}}

                {{#if group.links}}
                  <div class="sidebar-section-translations__caption">
                    {{i18n "sidebar.sections.custom.localizations.link_label"}}
                  </div>

                  {{#each group.links key="link.objectId" as |entry|}}
                    <TranslationRow
                      @source={{entry.link.name}}
                      @localization={{entry.localization}}
                    />
                  {{/each}}
                {{/if}}
              </div>
            {{/each}}

            {{#if this.nextTranslationLocale}}
              <DButton
                @action={{this.addLanguage}}
                @icon="plus"
                @label="sidebar.sections.custom.localizations.add_language"
                class="btn-flat btn-text sidebar-section-translations__add-language"
              />
            {{/if}}
          </div>
        {{else}}
          <form class="form-horizontal sidebar-section-form">
            {{#if this.showSourceLocale}}
              <div class="sidebar-section-form__source-locale">
                <label for="section-source-locale">
                  {{i18n "sidebar.sections.custom.localizations.language"}}
                </label>

                <DSelect
                  @value={{this.transformedModel.locale}}
                  @onChange={{this.setSourceLocale}}
                  @includeNone={{false}}
                  class="sidebar-section-form__source-locale-select"
                  id="section-source-locale"
                  as |select|
                >
                  {{#each this.sourceLocaleOptions as |locale|}}
                    <select.Option
                      @value={{locale.value}}
                    >{{locale.name}}</select.Option>
                  {{/each}}
                </DSelect>

                <p class="sidebar-section-form__source-locale-description">
                  {{i18n
                    "sidebar.sections.custom.localizations.language_description"
                  }}
                </p>
              </div>
            {{/if}}

            {{#unless this.transformedModel.hideTitleInput}}
              <div class="sidebar-section-form__input-wrapper">
                <label for="section-name">
                  {{i18n "sidebar.sections.custom.title.label"}}
                </label>

                <Input
                  name="section-name"
                  @type="text"
                  @value={{this.transformedModel.title}}
                  class={{this.transformedModel.titleCssClass}}
                  id="section-name"
                  {{on
                    "input"
                    (withEventValue (fn (mut this.transformedModel.title)))
                  }}
                />

                {{#if this.transformedModel.invalidTitleMessage}}
                  <div class="title warning">
                    {{this.transformedModel.invalidTitleMessage}}
                  </div>
                {{/if}}
              </div>
            {{/unless}}

            <div
              id="section-links-label"
              class="sidebar-section-form__links-label"
            >
              {{i18n "sidebar.sections.custom.links.title"}}
            </div>

            <DReorderableListGroup @onMove={{this.handleMove}} as |group|>
              <DReorderableList
                @group={{group}}
                @listId="primary"
                @listLabel={{i18n "sidebar.sections.custom.links.title"}}
                @items={{this.activeLinks}}
                @key="objectId"
                @label={{this.linkName}}
                @controls="manual"
                @tag="div"
                @role="table"
                @itemTag="div"
                @itemRole="row"
                @rowClass="sidebar-section-form-link row-wrapper"
                aria-labelledby="section-links-label"
                aria-rowcount={{this.activeLinks.length}}
                class="sidebar-section-form__links-wrapper"
              >
                <:header>
                  {{! The list element around this block carries the table role
                      through its role argument, which the static rule cannot
                      see from here. }}
                  {{! eslint-disable-next-line ember/template-require-context-role }}
                  <div class="row-wrapper header" role="row">
                    <div
                      class="input-group link-icon"
                      role="columnheader"
                      aria-sort="none"
                    >
                      {{! eslint-disable-next-line ember/template-no-nested-interactive }}
                      <label>{{i18n
                          "sidebar.sections.custom.links.icon.label"
                        }}</label>
                    </div>

                    <div
                      class="input-group link-name"
                      role="columnheader"
                      aria-sort="none"
                    >
                      {{! eslint-disable-next-line ember/template-no-nested-interactive }}
                      <label>{{i18n
                          "sidebar.sections.custom.links.name.label"
                        }}</label>
                    </div>

                    <div
                      class="input-group link-url"
                      role="columnheader"
                      aria-sort="none"
                    >
                      {{! eslint-disable-next-line ember/template-no-nested-interactive }}
                      <label>{{i18n
                          "sidebar.sections.custom.links.value.label"
                        }}</label>
                    </div>
                  </div>
                </:header>
                <:default as |link row|>
                  <SectionFormLink
                    @row={{row}}
                    @link={{link}}
                    @deleteLink={{this.deleteLink}}
                  />
                </:default>
              </DReorderableList>
              <DButton
                @action={{this.addLink}}
                @title="sidebar.sections.custom.links.add"
                @icon="plus"
                @label="sidebar.sections.custom.links.add"
                @ariaLabel="sidebar.sections.custom.links.add"
                class="btn-flat btn-text add-link"
              />

              {{#if this.transformedModel.sectionType}}
                <hr />
                <h3 id="section-secondary-links-label">{{i18n
                    "sidebar.sections.custom.more_menu"
                  }}</h3>
                {{! The rows resolve their columns through the wrapper's grid, so
                  a list rendered without one would collapse. }}
                <DReorderableList
                  @group={{group}}
                  @listId="secondary"
                  @listLabel={{i18n "sidebar.sections.custom.more_menu"}}
                  @items={{this.activeSecondaryLinks}}
                  @key="objectId"
                  @label={{this.linkName}}
                  @controls="manual"
                  @tag="div"
                  @role="table"
                  @itemTag="div"
                  @itemRole="row"
                  @rowClass="sidebar-section-form-link row-wrapper"
                  aria-labelledby="section-secondary-links-label"
                  aria-rowcount={{this.activeSecondaryLinks.length}}
                  class="sidebar-section-form__links-wrapper --secondary"
                >
                  <:default as |link row|>
                    <SectionFormLink
                      @row={{row}}
                      @link={{link}}
                      @deleteLink={{this.deleteLink}}
                    />
                  </:default>
                </DReorderableList>
                <DButton
                  @action={{this.addSecondaryLink}}
                  @title="sidebar.sections.custom.links.add"
                  @icon="plus"
                  @label="sidebar.sections.custom.links.add"
                  @ariaLabel="sidebar.sections.custom.links.add"
                  class="btn-flat btn-text add-link"
                />
              {{/if}}
            </DReorderableListGroup>

            {{#if this.canTranslate}}
              <hr />

              <DButton
                @action={{this.showTranslations}}
                @icon="globe"
                @translatedLabel={{this.translationsLabel}}
                class="btn-flat btn-text sidebar-section-form__manage-translations"
              >
                {{#if this.missingTranslationCount}}
                  <span class="sidebar-section-form__translations-incomplete">
                    {{i18n
                      "sidebar.sections.custom.localizations.incomplete"
                      count=this.missingTranslationCount
                    }}
                  </span>
                {{/if}}
              </DButton>
            {{/if}}
          </form>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @action={{this.save}}
          @label="sidebar.sections.custom.save"
          @ariaLabel="sidebar.sections.custom.save"
          @disabled={{not this.transformedModel.valid}}
          id="save-section"
          class="btn-primary"
        />
        {{#if this.currentUser.admin}}
          <div
            class="mark-public-wrapper
              {{if this.transformedModel.sectionType '-disabled'}}"
          >
            <label class="checkbox-label">
              {{#if this.transformedModel.sectionType}}
                <DTooltip
                  @content={{i18n "sidebar.sections.custom.always_public"}}
                  class="always-public-tooltip"
                >
                  <:trigger>
                    {{dIcon "square-check"}}
                    <span>{{i18n "sidebar.sections.custom.public"}}</span>
                  </:trigger>
                </DTooltip>
              {{else}}
                <Input
                  @type="checkbox"
                  @checked={{this.transformedModel.public}}
                  class="mark-public"
                  disabled={{this.transformedModel.sectionType}}
                  {{on "change" this.setPublic}}
                />
                <span>{{i18n "sidebar.sections.custom.public"}}</span>
              {{/if}}
            </label>
          </div>
        {{/if}}
        {{#if this.canDelete}}
          <DButton
            @icon="trash-can"
            @action={{this.delete}}
            @label="sidebar.sections.custom.delete"
            @ariaLabel="sidebar.sections.custom.delete"
            id="delete-section"
            class="btn-danger delete"
          />
        {{/if}}
        {{#if this.transformedModel.sectionType}}
          <DButton
            @action={{this.resetToDefault}}
            @icon="arrow-rotate-left"
            @title="sidebar.sections.custom.links.reset"
            @label="sidebar.sections.custom.links.reset"
            @ariaLabel="sidebar.sections.custom.links.reset"
            class="btn-flat btn-text reset-link"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
