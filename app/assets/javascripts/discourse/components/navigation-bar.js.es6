import Component from "@ember/component";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import DiscourseURL from "discourse/lib/url";
import { renderedConnectorsFor } from "discourse/lib/plugin-connectors";

export default Component.extend({
  tagName: "ul",
  classNameBindings: [":nav", ":nav-pills"],
  elementId: "navigation-bar",

  init() {
    this._super(...arguments);
    this.set("connectors", renderedConnectorsFor("extra-nav-item", null, this));
  },

  @computed("filterMode", "navItems")
  selectedNavItem(filterMode, navItems) {
    if (filterMode.indexOf("top/") === 0) {
      filterMode = "top";
    }
    var item = navItems.find(
      i => i.get("filterMode").indexOf(filterMode) === 0
    );
    if (!item) {
      let connectors = this.connectors;
      let category = this.category;
      if (connectors && category) {
        connectors.forEach(c => {
          if (
            c.connectorClass &&
            typeof c.connectorClass.path === "function" &&
            typeof (c.connectorClass.displayName === "function")
          ) {
            let path = c.connectorClass.path(category);
            if (path.indexOf(filterMode) > 0) {
              item = {
                displayName: c.connectorClass.displayName()
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
    if (!this.expanded) {
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

        Ember.run.next(() => {
          if (!this.expanded) {
            return;
          }

          $(this.element.querySelector(".drop a")).on("click", () => {
            this.element.querySelector(".drop").style.display = "none";

            Ember.run.next(() => {
              if (!this.element || this.isDestroying || this.isDestroyed) {
                return;
              }
              this.set("expanded", false);
            });

            return true;
          });

          $(window).on("click.navigation-bar", () => {
            this.set("expanded", false);
            return true;
          });
        });
      }
    }
  }
});
