import TextField from "discourse/components/text-field";

/**
  Same as text-field, but with special features for a password input.
  Be sure to test on a variety of browsers and operating systems when changing this logic.
**/
export default class PasswordField extends TextField {
  canToggle = false;

  keyPress(e) {
    if (
      (e.which >= 65 && e.which <= 90 && !e.shiftKey) ||
      (e.which >= 97 && e.which <= 122 && e.shiftKey)
    ) {
      this.set("canToggle", true);
      this.set("capsLockOn", true);
    } else if (
      (e.which >= 65 && e.which <= 90 && e.shiftKey) ||
      (e.which >= 97 && e.which <= 122 && !e.shiftKey)
    ) {
      this.set("canToggle", true);
      this.set("capsLockOn", false);
    }
  }

  keyUp(e) {
    if (e.which === 20 && this.canToggle) {
      this.toggleProperty("capsLockOn");
    }
  }

  focusOut() {
    this.set("capsLockOn", false);
  }

  focusIn() {
    this.set("canToggle", false); // can't know the state of caps lock yet. keyPress will figure it out.
  }
}
