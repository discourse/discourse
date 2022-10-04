import { on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";
import deprecated from "discourse-common/lib/deprecated";

export default Component.extend({
  @on("init")
  _init() {
    if (!this.get("site.mobileView")) {
      let classes = this.desktopClass;
      if (classes) {
        classes = classes.split(" ");
        this.set("classNames", classes);
      }
    }
    if (this.currentPath) {
      deprecated("{{mobile-nav}} no longer requires the currentPath property", {
        since: "2.7.0.beta4",
        dropFrom: "2.9.0.beta1",
      });
    }
  },

  tagName: "ul",
  selectedHtml: null,

  classNames: ["mobile-nav"],

  router: service(),

  currentRouteChanged() {
    this.set("expanded", false);
    next(() => this._updateSelectedHtml());
  },

  _updateSelectedHtml() {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    const active = this.element.querySelector(".active");
    if (active && active.innerHTML) {
      this.set("selectedHtml", active.innerHTML);
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this._updateSelectedHtml();
    this.router.on("routeDidChange", this, this.currentRouteChanged);
  },

  willDestroyElement() {
    this.router.off("routeDidChange", this, this.currentRouteChanged);
  },

  actions: {
    toggleExpanded() {
      this.toggleProperty("expanded");

      next(() => {
        if (this.expanded) {
          $(window)
            .off("click.mobile-nav")
            .on("click.mobile-nav", (e) => {
              if (!this.element || this.isDestroying || this.isDestroyed) {
                return;
              }

              const expander = this.element.querySelector(".expander");
              if (expander && e.target !== expander) {
                this.set("expanded", false);
                $(window).off("click.mobile-nav");
              }
            });
        }
      });
    },
  },
});
