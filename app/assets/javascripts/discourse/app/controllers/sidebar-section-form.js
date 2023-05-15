import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { isEmpty } from "@ember/utils";
import { extractError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { sanitize } from "discourse/lib/text";
import { tracked } from "@glimmer/tracking";
import { A } from "@ember/array";
import { SIDEBAR_SECTION, SIDEBAR_URL } from "discourse/lib/constants";

const FULL_RELOAD_LINKS_REGEX = [/^\/my\/[a-z_\-\/]+$/, /^\/safe-mode$/];

class Section {
  @tracked title;
  @tracked links;

  constructor({ title, links, id, publicSection }) {
    this.title = title;
    this.public = publicSection;
    this.links = links;
    this.id = id;
  }

  get valid() {
    const validLinks =
      this.links.length > 0 && this.links.every((link) => link.valid);
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
      return I18n.t("sidebar.sections.custom.title.validation.blank");
    }
    if (this.#tooLongTitle) {
      return I18n.t("sidebar.sections.custom.title.validation.maximum", {
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

  constructor({ router, icon, name, value, id }) {
    this.router = router;
    this.icon = icon || "link";
    this.name = name;
    this.value = value;
    this.id = id;
    this.httpHost = "http://" + window.location.host;
    this.httpsHost = "https://" + window.location.host;
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
      return I18n.t("sidebar.sections.custom.links.icon.validation.blank");
    }
    if (this.#tooLongIcon) {
      return I18n.t("sidebar.sections.custom.links.icon.validation.maximum", {
        count: SIDEBAR_URL.max_icon_length,
      });
    }
  }

  get invalidNameMessage() {
    if (this.name === undefined) {
      return;
    }
    if (this.#blankName) {
      return I18n.t("sidebar.sections.custom.links.name.validation.blank");
    }
    if (this.#tooLongName) {
      return I18n.t("sidebar.sections.custom.links.name.validation.maximum", {
        count: SIDEBAR_URL.max_name_length,
      });
    }
  }

  get invalidValueMessage() {
    if (this.value === undefined) {
      return;
    }
    if (this.#blankValue) {
      return I18n.t("sidebar.sections.custom.links.value.validation.blank");
    }
    if (this.#tooLongValue) {
      return I18n.t("sidebar.sections.custom.links.value.validation.maximum", {
        count: SIDEBAR_URL.max_value_length,
      });
    }
    if (this.#invalidValue) {
      return I18n.t("sidebar.sections.custom.links.value.validation.invalid");
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

  get external() {
    return (
      this.value &&
      !(
        this.value.startsWith(this.httpHost) ||
        this.value.startsWith(this.httpsHost) ||
        this.value.startsWith("/")
      )
    );
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
    return (
      this.path &&
      (this.external ? !this.#validExternal() : !this.#validInternal())
    );
  }

  #validExternal() {
    try {
      return new URL(this.value);
    } catch {
      return false;
    }
  }

  #validInternal() {
    return (
      this.router.recognize(this.path).name !== "unknown" ||
      FULL_RELOAD_LINKS_REGEX.some((regex) => this.path.match(regex))
    );
  }
}

export default Controller.extend(ModalFunctionality, {
  dialog: service(),
  router: service(),

  onShow() {
    this.setProperties({
      flashText: null,
      flashClass: null,
    });
    this.model = this.initModel();
  },

  onClose() {
    this.model = null;
  },

  initModel() {
    if (this.model) {
      return new Section({
        title: this.model.title,
        publicSection: this.model.public,
        links: A(
          this.model.links.map(
            (link) =>
              new SectionLink({
                router: this.router,
                icon: link.icon,
                name: link.name,
                value: link.value,
                id: link.id,
              })
          )
        ),
        id: this.model.id,
      });
    } else {
      return new Section({
        links: A([new SectionLink({ router: this.router })]),
      });
    }
  },

  create() {
    return ajax(`/sidebar_sections`, {
      type: "POST",
      contentType: "application/json",
      dataType: "json",
      data: JSON.stringify({
        title: this.model.title,
        public: this.model.public,
        links: this.model.links.map((link) => {
          return {
            icon: link.icon,
            name: link.name,
            value: link.path,
          };
        }),
      }),
    })
      .then((data) => {
        this.currentUser.updateSidebarSections(
          this.currentUser.sidebar_sections.concat(data.sidebar_section)
        );
        this.send("closeModal");
      })
      .catch((e) =>
        this.setProperties({
          flashText: sanitize(extractError(e)),
          flashClass: "error",
        })
      );
  },

  update() {
    return ajax(`/sidebar_sections/${this.model.id}`, {
      type: "PUT",
      contentType: "application/json",
      dataType: "json",
      data: JSON.stringify({
        title: this.model.title,
        public: this.model.public,
        links: this.model.links.map((link) => {
          return {
            id: link.id,
            icon: link.icon,
            name: link.name,
            value: link.path,
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
        this.currentUser.updateSidebarSections(newSidebarSections);
        this.send("closeModal");
      })
      .catch((e) =>
        this.setProperties({
          flashText: sanitize(extractError(e)),
          flashClass: "error",
        })
      );
  },

  get activeLinks() {
    return this.model.links.filter((link) => !link._destroy);
  },

  get header() {
    return this.model.id
      ? "sidebar.sections.custom.edit"
      : "sidebar.sections.custom.add";
  },

  actions: {
    addLink() {
      this.model.links.pushObject(new SectionLink({ router: this.router }));
    },

    deleteLink(link) {
      if (link.id) {
        link._destroy = "1";
      } else {
        this.model.links.removeObject(link);
      }
    },

    save() {
      this.model.id ? this.update() : this.create();
    },

    delete() {
      return this.dialog.yesNoConfirm({
        message: I18n.t("sidebar.sections.custom.delete_confirm"),
        didConfirm: () => {
          return ajax(`/sidebar_sections/${this.model.id}`, {
            type: "DELETE",
          })
            .then((data) => {
              const newSidebarSections =
                this.currentUser.sidebar_sections.filter((section) => {
                  return section.id !== data["sidebar_section"].id;
                });
              this.currentUser.updateSidebarSections(newSidebarSections);
              this.send("closeModal");
            })
            .catch((e) =>
              this.setProperties({
                flashText: sanitize(extractError(e)),
                flashClass: "error",
              })
            );
        },
      });
    },
  },
});
