import Component from "@ember/component";
import cookie from "discourse/lib/cookie";
import { bind } from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["create-account-body"],

  // used for animating the label inside of inputs
  userInputFocus(event) {
    const userField = event.target.parentElement.parentElement;
    if (!userField.classList.contains("value-entered")) {
      userField.classList.toggle("value-entered");
    }
  },

  // used for animating the label inside of inputs
  userInputFocusOut(event) {
    const userField = event.target.parentElement.parentElement;
    if (
      event.target.value.length === 0 &&
      userField.classList.contains("value-entered")
    ) {
      userField.classList.toggle("value-entered");
    }
  },

  @bind
  actionOnEnter(event) {
    if (!this.disabled && event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();
      this.action();
      return false;
    }
  },

  @bind
  selectKitFocus(event) {
    const target = document.getElementById(event.target.getAttribute("for"));
    if (target?.classList.contains("select-kit")) {
      event.preventDefault();
      target.querySelector(".select-kit-header").click();
    }
  },

  didInsertElement() {
    this._super(...arguments);

    if (cookie("email")) {
      this.set("email", cookie("email"));
    }

    let userTextFields = document.getElementsByClassName("user-fields")[0];

    if (userTextFields) {
      userTextFields =
        userTextFields.getElementsByClassName("ember-text-field");
    }

    if (userTextFields) {
      for (let element of userTextFields) {
        element.addEventListener("focus", this.userInputFocus);
        element.addEventListener("focusout", this.userInputFocusOut);
      }
    }

    this.element.addEventListener("keydown", this.actionOnEnter);
    this.element.addEventListener("click", this.selectKitFocus);
  },

  willDestroyElement() {
    this._super(...arguments);

    this.element.removeEventListener("keydown", this.actionOnEnter);
    this.element.removeEventListener("click", this.selectKitFocus);

    let userTextFields = document.getElementsByClassName("user-fields")[0];

    if (userTextFields) {
      userTextFields =
        userTextFields.getElementsByClassName("ember-text-field");
    }

    if (userTextFields) {
      for (let element of userTextFields) {
        element.removeEventListener("focus", this.userInputFocus);
        element.removeEventListener("focusout", this.userInputFocusOut);
      }
    }
  },
});
