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
    this._resizeObserver = null;
  },

  didInsertElement() {
    if (!this.site.mobileView) {
      // we want to reorder these elements based on their width, which can vary based on settings and viewport

      let navContainer = document.querySelector(".navigation-container");

      if (navContainer) {
        if ("ResizeObserver" in window) {
          let navElements = {};

          navElements["navWrap"] = navContainer;
          navElements["navBread"] = document.querySelector(
            ".category-breadcrumb"
          );
          navElements["navPills"] = document.querySelector(".nav-pills");
          navElements["navControls"] = document.querySelector(
            ".navigation-controls"
          );

          this._resizeObserver = new ResizeObserver((entries) => {
            window.requestAnimationFrame(() => {
              for (let entry of entries) {
                if (entry.contentRect && entry.contentRect.width) {
                  for (const [key, value] of Object.entries(navElements)) {
                    if (value === entry.target) {
                      navElements[key]["width"] = entry.contentRect.width;
                    }
                  }
                }
              }

              let childrenWidth =
                navElements["navPills"]["width"] +
                navElements["navBread"]["width"] +
                navElements["navControls"]["width"];

              let wrapWidth = navElements["navWrap"]["width"];

              if (wrapWidth < childrenWidth) {
                navElements["navPills"].style.order = "3";
              } else {
                navElements["navPills"].style.order = "unset";
              }
            });
          });

          Object.values(navElements).forEach((element) => {
            this._resizeObserver.observe(element);
          });
        }
      }
    }
  },

  willDestroyElement() {
    this._resizeObserver?.disconnect();
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
