import { cached, tracked } from "@glimmer/tracking";
import { A } from "@ember/array";
import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import SectionFormLink from "discourse/components/sidebar/section-form-link";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { SIDEBAR_SECTION, SIDEBAR_URL } from "discourse/lib/constants";
import { afterRender, bind } from "discourse/lib/decorators";
import { sanitize } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

class Section {
  @tracked title;
  @tracked links;
  @tracked secondaryLinks;

  constructor({
    title,
    links,
    secondaryLinks,
    id,
    publicSection,
    sectionType,
    hideTitleInput,
  }) {
    this.title = title;
    this.public = publicSection;
    this.sectionType = sectionType;
    this.links = links;
    this.secondaryLinks = secondaryLinks;
    this.id = id;
    this.hideTitleInput = hideTitleInput;
  }

  get valid() {
    const allLinks = this.links
      .filter((link) => !link._destroy)
      .concat(this.secondaryLinks?.filter((link) => !link._destroy) || []);
    const validLinks =
      allLinks.length > 0 && allLinks.every((link) => link.valid);
    return this.validTitle && validLinks;
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

class SectionLink {
  @tracked icon;
  @tracked name;
  @tracked value;
  @tracked _destroy;

  constructor({ router, icon: iconName, name, value, id, objectId, segment }) {
    this.router = router;
    this.icon = iconName || "link";
    this.name = name;
    this.value = value;
    this.id = id;
    this.httpHost = "http://" + window.location.host;
    this.httpsHost = "https://" + window.location.host;
    this.objectId = objectId;
    this.segment = segment;
  }

  get path() {
    return this.value?.replace(this.httpHost, "").replace(this.httpsHost, "");
  }

  get valid() {
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

export default class SidebarSectionForm extends Component {
  @service dialog;
  @service router;

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
        }, A()),
        secondaryLinks: section.links.reduce((acc, link) => {
          if (link.segment === "secondary") {
            this.nextObjectId++;
            acc.push(this.initLink(link));
          }
          return acc;
        }, A()),
        id: section.id,
        hideTitleInput: this.model.hideSectionHeader,
      });
    } else {
      return new Section({
        links: A([
          new SectionLink({
            router: this.router,
            objectId: this.nextObjectId,
            segment: "primary",
          }),
        ]),
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
    });
  }

  create() {
    return ajax(`/sidebar_sections`, {
      type: "POST",
      contentType: "application/json",
      dataType: "json",
      data: JSON.stringify({
        title: this.transformedModel.title,
        public: this.transformedModel.public,
        links: this.transformedModel.links.map((link) => {
          return {
            icon: link.icon,
            name: link.name,
            value: link.path,
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
      .querySelector(`[data-row-id="${id}"] .icon-picker summary`)
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

    if (this.draggedLink.isPrimary) {
      this.transformedModel.links.removeObject(this.draggedLink);
    } else {
      this.transformedModel.secondaryLinks?.removeObject(this.draggedLink);
    }

    if (targetLink.isPrimary) {
      const toPosition = this.transformedModel.links.indexOf(targetLink);
      this.draggedLink.segment = "primary";
      this.transformedModel.links.insertAt(
        above ? toPosition : toPosition + 1,
        this.draggedLink
      );
    } else {
      this.draggedLink.segment = "secondary";
      const toPosition =
        this.transformedModel.secondaryLinks.indexOf(targetLink);
      this.transformedModel.secondaryLinks.insertAt(
        above ? toPosition : toPosition + 1,
        this.draggedLink
      );
    }
  }

  get canDelete() {
    return this.transformedModel.id && !this.transformedModel.sectionType;
  }

  @bind
  deleteLink(link) {
    if (link.id) {
      link._destroy = "1";
    } else {
      if (link.isPrimary) {
        this.transformedModel.links.removeObject(link);
      } else {
        this.transformedModel.secondaryLinks.removeObject(link);
      }
    }
  }

  @action
  addLink() {
    this.nextObjectId = this.nextObjectId + 1;
    this.transformedModel.links.pushObject(
      new SectionLink({
        router: this.router,
        objectId: this.nextObjectId,
        segment: "primary",
      })
    );

    this.focusNewRowInput(this.nextObjectId);
  }

  @action
  addSecondaryLink() {
    this.nextObjectId = this.nextObjectId + 1;
    this.transformedModel.secondaryLinks.pushObject(
      new SectionLink({
        router: this.router,
        objectId: this.nextObjectId,
        segment: "secondary",
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
            this.currentUser.sidebar_sections.shiftObject();
            this.currentUser.sidebar_sections.unshiftObject(
              data["sidebar_section"]
            );
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
      class="sidebar-section-form-modal"
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
          <div
            role="table"
            aria-rowcount={{this.activeLinks.length}}
            class="sidebar-section-form__links-wrapper"
          >

            <div class="row-wrapper header" role="row">
              <div
                class="input-group link-icon"
                role="columnheader"
                aria-sort="none"
              >
                <label>{{i18n
                    "sidebar.sections.custom.links.icon.label"
                  }}</label>
              </div>

              <div
                class="input-group link-name"
                role="columnheader"
                aria-sort="none"
              >
                <label>{{i18n
                    "sidebar.sections.custom.links.name.label"
                  }}</label>
              </div>

              <div
                class="input-group link-url"
                role="columnheader"
                aria-sort="none"
              >
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
                    {{icon "square-check"}}
                    <span>{{i18n "sidebar.sections.custom.public"}}</span>
                  </:trigger>
                </DTooltip>
              {{else}}
                <Input
                  @type="checkbox"
                  @checked={{this.transformedModel.public}}
                  class="mark-public"
                  disabled={{this.transformedModel.sectionType}}
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
