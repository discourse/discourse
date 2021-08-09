import Component from "@ember/component";
import cookie from "discourse/lib/cookie";

export default Component.extend({
  classNames: ["create-account-body"],

  userInputFocus(event) {
    let label = event.target.parentElement.previousElementSibling;
    if (!label.classList.contains("value-entered")) {
      label.classList.toggle("value-entered");
    }
  },

  userInputFocusOut(event) {
    let label = event.target.parentElement.previousElementSibling;
    if (
      event.target.value.length === 0 &&
      label.classList.contains("value-entered")
    ) {
      label.classList.toggle("value-entered");
    }
  },

  didInsertElement() {
    this._super(...arguments);

    if (cookie("email")) {
      this.set("email", cookie("email"));
    }

    let userTextFields = document.getElementsByClassName("user-fields")[0];

    if (userTextFields) {
      userTextFields = userTextFields.getElementsByClassName(
        "ember-text-field"
      );
    }

    if (userTextFields) {
      for (let element of userTextFields) {
        element.addEventListener("focus", this.userInputFocus);
        element.addEventListener("focusout", this.userInputFocusOut);
      }
    }

    $(this.element).on("keydown.discourse-create-account", (e) => {
      if (!this.disabled && e.key === "Enter") {
        e.preventDefault();
        e.stopPropagation();
        this.action();
        return false;
      }
    });

    $(this.element).on("click.dropdown-user-field-label", "[for]", (event) => {
      const $element = $(event.target);
      const $target = $(`#${$element.attr("for")}`);

      if ($target.is(".select-kit")) {
        event.preventDefault();
        $target.find(".select-kit-header").trigger("click");
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    $(this.element).off("keydown.discourse-create-account");
    $(this.element).off("click.dropdown-user-field-label");

    let userTextFields = document.getElementsByClassName("user-fields")[0];

    if (userTextFields) {
      userTextFields = userTextFields.getElementsByClassName(
        "ember-text-field"
      );
    }

    if (userTextFields) {
      for (let element of userTextFields) {
        element.removeEventListener("focus", this.userInputFocus);
        element.removeEventListener("focusout", this.userInputFocusOut);
      }
    }
  },
});
