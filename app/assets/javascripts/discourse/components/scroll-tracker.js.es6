import Scrolling from "discourse/mixins/scrolling";

export default Ember.Component.extend(Scrolling, {
  didReceiveAttrs() {
    this._super();

    this.set("trackerName", `scroll-tracker-${this.get("name")}`);
  },

  didInsertElement() {
    this._super();

    this.bindScrolling({ name: this.get("name") });
  },

  didRender() {
    this._super();

    const data = this.session.get(this.get("trackerName"));
    if (data && data.position >= 0 && data.tag === this.get("tag")) {
      Ember.run.next(() => $(window).scrollTop(data.position + 1));
    }
  },

  willDestroyElement() {
    this._super();

    this.unbindScrolling(this.get("name"));
  },

  scrolled() {
    this._super();

    this.session.set(this.get("trackerName"), {
      position: $(window).scrollTop(),
      tag: this.get("tag")
    });
  }
});
