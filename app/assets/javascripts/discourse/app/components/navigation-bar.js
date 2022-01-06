import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import FilterModeMixin from "discourse/mixins/filter-mode";
import { next } from "@ember/runloop";

export default Component.extend(FilterModeMixin, {
  tagName: "ul",
  classNameBindings: [":nav", ":nav-pills"],
  elementId: "navigation-bar",

  init() {
    this._super(...arguments);
  },

  @discourseComputed("filterType", "navItems")
  selectedNavItem(filterType, navItems) {
    let item = navItems.find((i) => i.active === true);

    item = item || navItems.find((i) => i.get("filterType") === filterType);

    if (!item) {
      let connectors = this.connectors;
      let category = this.category;
      if (connectors && category) {
        connectors.forEach((c) => {
          if (
            c.connectorClass &&
            typeof c.connectorClass.path === "function" &&
            typeof c.connectorClass.displayName === "function"
          ) {
            let path = c.connectorClass.path(category);
            if (path.indexOf(filterType) > 0) {
              item = {
                displayName: c.connectorClass.displayName(),
              };
            }
          }
        });
      }
    }
    return item || navItems[0];
  },

  @observes("expanded")
  closedNav() {
    if (!this.expanded) {
      this.ensureDropClosed();
    }
  },

  ensureDropClosed() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.expanded) {
      this.set("expanded", false);
    }
    $(window).off("click.navigation-bar");
    DiscourseURL.appEvents.off("dom:clean", this, this.ensureDropClosed);
  },

  actions: {
    toggleDrop() {
      this.set("expanded", !this.expanded);

      if (this.expanded) {
        DiscourseURL.appEvents.on("dom:clean", this, this.ensureDropClosed);

        next(() => {
          if (!this.expanded) {
            return;
          }

          $(this.element.querySelector(".drop a")).on("click", () => {
            this.element.querySelector(".drop").style.display = "none";

            next(() => {
              this.ensureDropClosed();
            });
            return true;
          });

          $(window).on("click.navigation-bar", () => {
            this.ensureDropClosed();
            return true;
          });
        });
      }
    },
  },
});
