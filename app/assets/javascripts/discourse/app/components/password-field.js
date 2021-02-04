import TextField from "discourse/components/text-field";

/**
  Same as text-field, but with special features for a password input.
  Be sure to test on a variety of browsers and operating systems when changing this logic.
**/
export default TextField.extend({
  canToggle: false,

  keyPress(event) {
    if (
      (event.which >= 65 && event.which <= 90 && !event.shiftKey) ||
      (event.which >= 97 && event.which <= 122 && event.shiftKey)
    ) {
      this.set("canToggle", true);
      this.set("capsLockOn", true);
    } else if (
      (event.which >= 65 && event.which <= 90 && event.shiftKey) ||
      (event.which >= 97 && event.which <= 122 && !event.shiftKey)
    ) {
      this.set("canToggle", true);
      this.set("capsLockOn", false);
    }
  },

  keyUp(event) {
    this._super(event);

    if (event.which === 20 && this.canToggle) {
      this.toggleProperty("capsLockOn");
    }
  },

  focusOut() {
    this.set("capsLockOn", false);
  },

  focusIn() {
    this.set("canToggle", false); // can't know the state of caps lock yet. keyPress will figure it out.
  },
});
