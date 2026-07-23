/* eslint-disable ember/no-classic-components */
import { cached, tracked } from "@glimmer/tracking";
import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
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
import { removeValueFromArray } from "discourse/lib/array-tools";
import { SIDEBAR_SECTION, SIDEBAR_URL } from "discourse/lib/constants";
import { afterRender, bind } from "discourse/lib/decorators";
import { sanitize } from "discourse/lib/text";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { and, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DSelect from "discourse/ui-kit/d-select";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

class Section {
  @tracked title;
  @tracked public;
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
  }) {
    this.title = title;
    this.public = publicSection;
    this.sectionType = sectionType;
    this.links = links;
    this.secondaryLinks = secondaryLinks;
    this.id = id;
    this.hideTitleInput = hideTitleInput;
    this.localizations = localizations || [];
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

class SectionLocalization {
  @tracked locale;
  @tracked title;
  @tracked _destroy;

  constructor({ id, locale, title }) {
    this.id = id;
    this.locale = locale;
    this.title = title;
  }

  get valid() {
    return !isEmpty(this.locale) && !isEmpty(this.title) && !this.#tooLongTitle;
  }

  get invalidTitleMessage() {
    if (this.title === undefined) {
      return;
    }
    if (isEmpty(this.title)) {
      return i18n("sidebar.sections.custom.title.validation.blank");
    }
    if (this.#tooLongTitle) {
      return i18n("sidebar.sections.custom.title.validation.maximum", {
        count: SIDEBAR_SECTION.max_title_length,
      });
    }
  }

  get #tooLongTitle() {
    return this.title?.length > SIDEBAR_SECTION.max_title_length;
  }
}

class LinkLocalization {
  @tracked locale;
  @tracked name;
  @tracked _destroy;

  constructor({ id, locale, name }) {
    this.id = id;
    this.locale = locale;
    this.name = name;
  }

  get valid() {
    return !isEmpty(this.locale) && !isEmpty(this.name) && !this.#tooLongName;
  }

  get invalidNameMessage() {
    if (this.name === undefined) {
      return;
    }
    if (isEmpty(this.name)) {
      return i18n("sidebar.sections.custom.links.name.validation.blank");
    }
    if (this.#tooLongName) {
      return i18n("sidebar.sections.custom.links.name.validation.maximum", {
        count: SIDEBAR_URL.max_name_length,
      });
    }
  }

  get #tooLongName() {
    return this.name?.length > SIDEBAR_URL.max_name_length;
  }
}

class SectionLink {
  @tracked icon;
  @tracked name;
  @tracked value;
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

@tagName("")
export default class SidebarSectionForm extends Component {
  @service dialog;
  @service languageNameLookup;
  @service router;
  @service siteSettings;

  @tracked flash;
  @tracked flashType;

  nextObjectId = 0;

  @cached
  get transformedModel() {
    const section = this.model?.section;

    if (section) {
      return new Section({
        title: section.title,
        publicSection: section.public,
        sectionType: section.section_type,
        links: section.links.reduce((acc, link) => {
          if (link.segment === "primary") {
            this.nextObjectId++;
            acc.push(this.initLink(link));
          }
          return acc;
        }, []),
        secondaryLinks: section.links.reduce((acc, link) => {
          if (link.segment === "secondary") {
            this.nextObjectId++;
            acc.push(this.initLink(link));
          }
          return acc;
        }, []),
        id: section.id,
        hideTitleInput: this.model.hideSectionHeader,
        localizations: this.initLocalizations(
          section.localizations,
          SectionLocalization
        ),
      });
    } else {
      return new Section({
        links: [
          new SectionLink({
            router: this.router,
            objectId: this.nextObjectId,
            segment: "primary",
          }),
        ],
      });
    }
  }

  initLink(link) {
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
        localizations: this.serializeSectionLocalizations(),
        links: this.transformedModel.links.map((link) => {
          return {
            icon: link.icon,
            name: link.name,
            value: link.path,
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
    this.wasPublic || this.isPublic
      ? this.#updateWithConfirm()
      : this.#updateCall();
  }

  #updateWithConfirm() {
    return this.dialog.yesNoConfirm({
      message: this.isPublic
        ? i18n("sidebar.sections.custom.update_public_confirm")
        : i18n("sidebar.sections.custom.mark_as_private_confirm"),
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

  get activeLocalizations() {
    return this.transformedModel.localizations.filter(
      (localization) => !localization._destroy
    );
  }

  get localeOptions() {
    const configuredLocales =
      this.siteSettings.available_content_localization_locales?.map(
        (locale) => locale.value
      ) ||
      this.siteSettings.content_localization_supported_locales
        ?.split("|")
        .filter(Boolean) ||
      [];
    const locales = new Set(configuredLocales);

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

    return [...locales]
      .filter((locale) => locale && locale !== this.siteSettings.default_locale)
      .map((locale) => ({
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

  get canAddSectionLocalization() {
    return this.nextLocale(this.transformedModel.localizations) !== "";
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
      .querySelector(`[data-row-id="${id}"] .d-icon-grid-picker-trigger`)
      .focus();
  }

  @bind
  setDraggedLink(link) {
    this.draggedLink = link;
  }

  @bind
  reorder(targetLink, above) {
    if (this.draggedLink === targetLink) {
      return;
    }

    const links = this.draggedLink.isPrimary
      ? this.transformedModel.links
      : this.transformedModel.secondaryLinks;

    removeValueFromArray(links, this.draggedLink);

    const toPosition = links.indexOf(targetLink);
    this.draggedLink.segment = targetLink.isPrimary ? "primary" : "secondary";

    links.splice(above ? toPosition : toPosition + 1, 0, this.draggedLink);
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

  @bind
  deleteLocalization(localization) {
    if (localization.id) {
      localization._destroy = "1";
    } else {
      removeValueFromArray(this.transformedModel.localizations, localization);
    }
  }

  @bind
  deleteLinkLocalization(link, localization) {
    if (localization.id) {
      localization._destroy = "1";
    } else {
      removeValueFromArray(link.localizations, localization);
    }
  }

  @bind
  addLinkLocalization(link) {
    const locale = this.nextLocale(link.localizations);
    if (!locale) {
      return;
    }

    link.localizations.push(
      new LinkLocalization({
        locale,
      })
    );
  }

  @action
  addLocalization() {
    const locale = this.nextLocale(this.transformedModel.localizations);
    if (!locale) {
      return;
    }

    this.transformedModel.localizations.push(
      new SectionLocalization({
        locale,
      })
    );
  }

  nextLocale(localizations) {
    const selectedLocales = localizations
      .filter((localization) => !localization._destroy)
      .map((localization) => localization.locale);

    return (
      this.localeOptions.find(
        (locale) => !selectedLocales.includes(locale.value)
      )?.value || ""
    );
  }

  @bind
  setSectionLocalizationLocale(localization, locale) {
    this.setLocalizationLocale(
      this.transformedModel.localizations,
      localization,
      locale
    );
  }

  @bind
  setLinkLocalizationLocale(link, localization, locale) {
    this.setLocalizationLocale(link.localizations, localization, locale);
  }

  @bind
  isSectionLocalizationLocaleDisabled(localization, locale) {
    return this.isLocalizationLocaleSelected(
      this.transformedModel.localizations,
      localization,
      locale
    );
  }

  @bind
  isLinkLocalizationLocaleDisabled(link, localization, locale) {
    return this.isLocalizationLocaleSelected(
      link.localizations,
      localization,
      locale
    );
  }

  setLocalizationLocale(localizations, localization, locale) {
    if (
      !this.isLocalizationLocaleSelected(localizations, localization, locale)
    ) {
      localization.locale = locale;
    }
  }

  isLocalizationLocaleSelected(localizations, localization, locale) {
    return localizations
      .filter((existingLocalization) => {
        return (
          existingLocalization !== localization &&
          !existingLocalization._destroy
        );
      })
      .some((existingLocalization) => existingLocalization.locale === locale);
  }

  serializeSectionLocalizations() {
    if (!this.showLocalizations) {
      return [];
    }

    return this.transformedModel.localizations.map((localization) => ({
      id: localization.id,
      locale: localization.locale,
      title: localization.title,
      _destroy: localization._destroy,
    }));
  }

  serializeLinkLocalizations(link) {
    if (!this.showLinkLocalizations || !link.canLocalize) {
      return [];
    }

    return link.localizations.map((localization) => ({
      id: localization.id,
      locale: localization.locale,
      name: localization.name,
      _destroy: localization._destroy,
    }));
  }

  @action
  addLink() {
    this.nextObjectId = this.nextObjectId + 1;
    this.transformedModel.links.push(
      new SectionLink({
        router: this.router,
        objectId: this.nextObjectId,
        segment: "primary",
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
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @title={{i18n this.header}}
      class="sidebar-section-form-modal --large"
    >
      <:body>
        <form class="form-horizontal sidebar-section-form">
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
          {{#if this.showLocalizations}}
            <div class="sidebar-section-form__localizations">
              {{#each this.activeLocalizations as |localization|}}
                <div class="sidebar-section-form__localization-row">
                  <DSelect
                    @value={{localization.locale}}
                    @onChange={{fn
                      this.setSectionLocalizationLocale
                      localization
                    }}
                    @includeNone={{false}}
                    class="sidebar-section-form__localization-locale"
                    aria-label={{i18n
                      "sidebar.sections.custom.localizations.locale"
                    }}
                    as |select|
                  >
                    {{#each this.localeOptions as |locale|}}
                      <select.Option
                        @value={{locale.value}}
                        disabled={{this.isSectionLocalizationLocaleDisabled
                          localization
                          locale.value
                        }}
                      >{{locale.name}}</select.Option>
                    {{/each}}
                  </DSelect>

                  <Input
                    @type="text"
                    @value={{localization.title}}
                    class="sidebar-section-form__localization-value"
                    placeholder={{i18n
                      "sidebar.sections.custom.localizations.title_label"
                    }}
                    aria-label={{i18n
                      "sidebar.sections.custom.localizations.title_label"
                    }}
                    {{on
                      "input"
                      (withEventValue (fn (mut localization.title)))
                    }}
                  />

                  <DButton
                    @icon="trash-can"
                    @action={{fn this.deleteLocalization localization}}
                    @title="sidebar.sections.custom.localizations.remove"
                    class="btn-flat delete-link remove-localization"
                  />
                </div>

                {{#if localization.invalidTitleMessage}}
                  <div role="alert" aria-live="assertive" class="title warning">
                    {{localization.invalidTitleMessage}}
                  </div>
                {{/if}}
              {{/each}}

              {{#if this.canAddSectionLocalization}}
                <DButton
                  @action={{this.addLocalization}}
                  @title="sidebar.sections.custom.localizations.add_section"
                  @icon="plus"
                  @label="sidebar.sections.custom.localizations.add_section"
                  class="btn-flat btn-text add-localization"
                />
              {{/if}}
            </div>
            <hr />
          {{/if}}

          <div
            id="section-links-label"
            class="sidebar-section-form__links-label"
          >
            {{i18n "sidebar.sections.custom.links.title"}}
          </div>

          <div
            role="table"
            aria-labelledby="section-links-label"
            aria-rowcount={{this.activeLinks.length}}
            class="sidebar-section-form__links-wrapper"
          >

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

            {{#each this.activeLinks as |link|}}
              <SectionFormLink
                @link={{link}}
                @deleteLink={{this.deleteLink}}
                @reorderCallback={{this.reorder}}
                @setDraggedLinkCallback={{this.setDraggedLink}}
                @showLocalizations={{and
                  this.showLinkLocalizations
                  link.canLocalize
                }}
                @localeOptions={{this.localeOptions}}
                @deleteLocalization={{this.deleteLinkLocalization}}
                @addLocalization={{this.addLinkLocalization}}
                @setLocalizationLocale={{this.setLinkLocalizationLocale}}
                @isLocalizationLocaleDisabled={{this.isLinkLocalizationLocaleDisabled}}
              />
            {{/each}}

          </div>
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
            <h3>{{i18n "sidebar.sections.custom.more_menu"}}</h3>
            {{#each this.activeSecondaryLinks as |link|}}
              <SectionFormLink
                @link={{link}}
                @deleteLink={{this.deleteLink}}
                @reorderCallback={{this.reorder}}
                @setDraggedLinkCallback={{this.setDraggedLink}}
                @showLocalizations={{and
                  this.showLinkLocalizations
                  link.canLocalize
                }}
                @localeOptions={{this.localeOptions}}
                @deleteLocalization={{this.deleteLinkLocalization}}
                @addLocalization={{this.addLinkLocalization}}
                @setLocalizationLocale={{this.setLinkLocalizationLocale}}
                @isLocalizationLocaleDisabled={{this.isLinkLocalizationLocaleDisabled}}
              />
            {{/each}}
            <DButton
              @action={{this.addSecondaryLink}}
              @title="sidebar.sections.custom.links.add"
              @icon="plus"
              @label="sidebar.sections.custom.links.add"
              @ariaLabel="sidebar.sections.custom.links.add"
              class="btn-flat btn-text add-link"
            />
          {{/if}}
        </form>
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
        {{#if (and this.currentUser.admin)}}
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
