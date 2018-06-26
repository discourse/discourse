import { on, observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @on("init")
  _init() {
    if (!this.get("site.mobileView")) {
      var classes = this.get("desktopClass");
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
    Em.run.next(() => this._updateSelectedHtml());
  },

  _updateSelectedHtml() {
    const active = this.$(".active");
    if (active && active.html) {
      this.set("selectedHtml", active.html());
    }
  },

  didInsertElement() {
    this._updateSelectedHtml();
  },

  actions: {
    toggleExpanded() {
      this.toggleProperty("expanded");

      Em.run.next(() => {
        if (this.get("expanded")) {
          $(window)
            .off("click.mobile-nav")
            .on("click.mobile-nav", e => {
              let expander = this.$(".expander");
              expander = expander && expander[0];
              if ($(e.target)[0] !== expander) {
                this.set("expanded", false);
                $(window).off("click.mobile-nav");
              }
            });
        }
      });
    }
  }
});
