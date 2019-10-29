import Component from "@ember/component";
import { on, observes } from "ember-addons/ember-computed-decorators";

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

  @observes("currentPath")
  currentPathChanged() {
    this.set("expanded", false);
    Ember.run.next(() => this._updateSelectedHtml());
  },

  _updateSelectedHtml() {
    const active = this.element.querySelector(".active");
    if (active && active.innerHTML) {
      this.set("selectedHtml", active.innerHTML);
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this._updateSelectedHtml();
  },

  actions: {
    toggleExpanded() {
      this.toggleProperty("expanded");

      Ember.run.next(() => {
        if (this.expanded) {
          $(window)
            .off("click.mobile-nav")
            .on("click.mobile-nav", e => {
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
    }
  }
});
