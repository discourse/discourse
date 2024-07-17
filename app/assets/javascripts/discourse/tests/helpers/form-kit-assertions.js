import { capitalize } from "@ember/string";
import QUnit from "qunit";
import { query } from "discourse/tests/helpers/qunit-helpers";

class FieldHelper {
  constructor(element, context) {
    this.element = element;
    this.context = context;
  }

  get value() {
    switch (this.element.dataset.controlType) {
      case "image": {
        return this.element
          .querySelector(".form-kit__control-image a.lightbox")
          .getAttribute("href");
      }
      case "radio-group": {
        return this.element.querySelector(".form-kit__control-radio:checked")
          ?.value;
      }
      case "password":
        return this.element.querySelector(".form-kit__control-password").value;
      case "input-number":
      case "input-text":
        return this.element.querySelector(".form-kit__control-input").value;
      case "icon": {
        return this.element.querySelector(
          ".form-kit__control-icon .select-kit-header"
        )?.dataset?.value;
      }
      case "question": {
        return (
          this.element.querySelector(".form-kit__control-radio:checked")
            ?.value === "true"
        );
      }
      case "toggle": {
        return (
          this.element
            .querySelector(".form-kit__control-toggle")
            .getAttribute("aria-checked") === "true"
        );
      }
      case "textarea": {
        return this.element.querySelector(".form-kit__control-textarea").value;
      }
      case "code": {
        return this.element.querySelector(
          ".form-kit__control-code .ace_text-input"
        ).value;
      }
      case "composer": {
        return this.element.querySelector(
          ".form-kit__control-composer .d-editor-input"
        ).value;
      }
      case "select": {
        return this.element.querySelector(".form-kit__control-select").value;
      }
      case "menu": {
        return this.element.querySelector(".form-kit__control-menu").dataset
          .value;
      }
      case "checkbox": {
        return this.element.querySelector(".form-kit__control-checkbox")
          .checked;
      }
    }
  }

  get isDisabled() {
    return this.element.dataset.disabled === "";
  }

  hasCharCounter(current, max, message) {
    this.context
      .dom(this.element.querySelector(".form-kit__char-counter"))
      .includesText(`${current}/${max}`, message);
  }

  hasError(error, message) {
    this.context
      .dom(this.element.querySelector(".form-kit__errors"))
      .includesText(error, message);
  }

  hasNoError(message) {
    this.context
      .dom(this.element.querySelector(".form-kit__errors"))
      .doesNotExist(message);
  }

  doesNotExist(message) {
    this.context.dom(this.element).doesNotExist(message);
  }

  exists(message) {
    this.context.dom(this.element).exists(message);
  }
}

class FormHelper {
  constructor(selector, context) {
    this.context = context;
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  hasErrors(fields, assertionMessage) {
    const messages = Object.keys(fields).map((name) => {
      return `${capitalize(name)}: ${fields[name]}`;
    });

    this.context
      .dom(this.element.querySelector(".form-kit__errors-summary-list"))
      .hasText(messages.join(" "), assertionMessage);
  }

  hasNoErrors(message) {
    this.context
      .dom(this.element.querySelector(".form-kit__errors-summary-list"))
      .doesNotExist(message);
  }

  field(name) {
    return new FieldHelper(
      query(`.form-kit__field[data-name="${name}"]`, this.element),
      this.context
    );
  }
}

export function setupFormKitAssertions() {
  QUnit.assert.form = function (selector = "form") {
    const form = new FormHelper(selector, this);
    return {
      hasErrors: (fields, message) => {
        form.hasErrors(fields, message);
      },
      hasNoErrors: (fields, message) => {
        form.hasNoErrors(fields, message);
      },
      field: (name) => {
        const field = form.field(name);

        return {
          doesNotExist: (message) => {
            field.doesNotExist(message);
          },
          exists: (message) => {
            field.exists(message);
          },
          isDisabled: (message) => {
            this.ok(field.disabled, message);
          },
          isEnabled: (message) => {
            this.notOk(field.disabled, message);
          },
          hasError: (message) => {
            field.hasError(message);
          },
          hasCharCounter: (current, max, message) => {
            field.hasCharCounter(current, max, message);
          },
          hasNoError: (message) => {
            field.hasNoError(message);
          },
          hasValue: (value, message) => {
            this.deepEqual(field.value, value, message);
          },
        };
      },
    };
  };
}
