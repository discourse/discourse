import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    Ember.run.next(null, () => {
      const $this = $(this.element);

      if ($this) {
        $this.find("hr").remove();
        $this.ellipsis();
      }
    });
  }
});
