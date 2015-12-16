import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: ["visible::hidden", ":popup-menu", "extraClasses"],

  @on('didInsertElement')
  _setup() {
    this.appEvents.on("popup-menu:open", this, "_changeLocation");

    $('html').on(`mouseup.popup-menu-${this.get('elementId')}`, (e) => {
      const $target = $(e.target);
      if ($target.is("button") || this.$().has($target).length === 0) {
        this.sendAction('hide');
      }
    });
  },

  @on('willDestroyElement')
  _cleanup() {
    $('html').off(`mouseup.popup-menu-${this.get('elementId')}`);
    this.appEvents.off("popup-menu:open", this, "_changeLocation");
  },

  _changeLocation(location) {
    const $this = this.$();
    switch (location.position) {
      case "absolute": {
        $this.css({
          position: "absolute",
          top: location.top - $this.innerHeight() + 5,
          left: location.left,
        });
        break;
      }
      case "fixed": {
        $this.css({
          position: "fixed",
          top: location.top,
          left: location.left - $this.innerWidth(),
        });
        break;
      }
    }
  }
});
