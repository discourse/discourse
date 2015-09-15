import DButton from 'discourse/components/d-button';

export default DButton.extend({
  click() {
    const $target = this.$(),
          position = $target.position(),
          width = $target.innerWidth(),
          loc = {
            position: this.get('position') || "fixed",
            left: position.left + width,
            top: position.top
          };

    // TODO views/topic-footer-buttons is instantiating this via attachViewWithArgs
    // attachViewWithArgs does not set this.appEvents, it is undefined
    // this is a workaround but a proper fix probably depends on either deprecation
    // of attachViewClass et.el or correction of the methods to hydrate the depndencies
    this.appEvents = this.appEvents || this.container.lookup('app-events:main');
    this.appEvents.trigger("popup-menu:open", loc);
    this.sendAction("action");
  }
});
