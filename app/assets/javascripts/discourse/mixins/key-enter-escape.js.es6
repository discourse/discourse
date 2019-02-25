// A mixin where hitting ESC calls `cancelled` and ctrl+enter calls `save.
export default {
  keyDown(e) {
    if (e.which === 27) {
      this.cancelled();
      return false;
    } else if (e.which === 13 && (e.ctrlKey || e.metaKey)) {
      // CTRL+ENTER or CMD+ENTER
      this.save();
      return false;
    }
  }
};
