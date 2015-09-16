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

    this.appEvents.trigger("popup-menu:open", loc);
    this.sendAction("action");
  }
});
