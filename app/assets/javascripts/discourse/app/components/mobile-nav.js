import Component from "@ember/component";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import $ from "jquery";
import { on } from "discourse-common/utils/decorators";

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
    this._super(...arguments);
    this.router.off("routeDidChange", this, this.currentRouteChanged);
  },

  @action
  toggleExpanded(event) {
    event?.preventDefault();
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
});
