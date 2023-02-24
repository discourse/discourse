import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";
import { isEmpty } from "@ember/utils";
import { extractError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { sanitize } from "discourse/lib/text";
import { tracked } from "@glimmer/tracking";
import { A } from "@ember/array";

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
    return !isEmpty(this.title) && this.title.length <= 30;
  }

  get titleCssClass() {
    return this.title === undefined || this.validTitle ? "" : "warning";
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
    this.value = value ? `${this.protocolAndHost}${value}` : value;
    this.id = id;
  }

  get protocolAndHost() {
    return window.location.protocol + "//" + window.location.host;
  }

  get path() {
    return this.value?.replace(this.protocolAndHost, "");
  }

  get valid() {
    return this.validIcon && this.validName && this.validValue;
  }

  get validIcon() {
    return !isEmpty(this.icon) && this.icon.length <= 40;
  }

  get iconCssClass() {
    return this.icon === undefined || this.validIcon ? "" : "warning";
  }

  get validName() {
    return !isEmpty(this.name) && this.name.length <= 80;
  }

  get nameCssClass() {
    return this.name === undefined || this.validName ? "" : "warning";
  }

  get validValue() {
    return (
      !isEmpty(this.value) &&
      (this.value.startsWith(this.protocolAndHost) ||
        this.value.startsWith("/")) &&
      this.value.length <= 200 &&
      this.path &&
      this.router.recognize(this.path).name !== "unknown"
    );
  }

  get valueCssClass() {
    return this.value === undefined || this.validValue ? "" : "warning";
  }
}

export default Modal.extend({
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
        this.currentUser.sidebar_sections.pushObject(data.sidebar_section);
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
        this.currentUser.set("sidebar_sections", newSidebarSections);
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
              this.currentUser.set("sidebar_sections", newSidebarSections);
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
