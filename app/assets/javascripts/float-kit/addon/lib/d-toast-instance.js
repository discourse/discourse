import { setOwner } from "@ember/application";
import { TOAST } from "float-kit/lib/constants";
import uniqueId from "discourse/helpers/unique-id";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { modifier } from "ember-modifier";
import discourseLater from "discourse-common/lib/later";
import { cancel } from "@ember/runloop";

const CSS_TRANSITION_DELAY_MS = 500;
const TRANSITION_CLASS = "-fade-out";

export default class DToastInstance {
  @service toasts;

  options = null;
  id = uniqueId();
  autoCloseHandler = null;

  registerAutoClose = modifier((element) => {
    let innerHandler;

    this.autoCloseHandler = discourseLater(() => {
      element.classList.add(TRANSITION_CLASS);

      innerHandler = discourseLater(() => {
        this.close();
      }, CSS_TRANSITION_DELAY_MS);
    }, this.options.duration || TOAST.options.duration);

    return () => {
      cancel(innerHandler);
      cancel(this.autoCloseHandler);
    };
  });

  constructor(owner, options = {}) {
    setOwner(this, owner);
    this.options = { ...TOAST.options, ...options };
  }

  @action
  close() {
    this.toasts.close(this);
  }

  @action
  cancelAutoClose() {
    cancel(this.autoCloseHandler);
  }
}
