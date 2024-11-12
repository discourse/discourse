import { capitalize } from "@ember/string";
import { isBlank } from "@ember/utils";
import QUnit from "qunit";
import { query } from "discourse/tests/helpers/qunit-helpers";

class FieldsetHelper {
  constructor(element, context, name) {
    this.element = element;
    this.name = name;
    this.context = context;
  }

  hasTitle(title, message) {
    this.context
      .dom(this.element.querySelector(".form-kit__fieldset-title"))
      .hasText(title, message);
  }

  hasDescription(description, message) {
    this.context
      .dom(this.element.querySelector(".form-kit__fieldset-description"))
      .hasText(description, message);
  }

  includesText(content, message) {
    this.context.dom(this.element).includesText(content, message);
  }

  doesNotExist(message) {
    this.context.dom(this.element).doesNotExist(message);
  }

  exists(message) {
    this.context.dom(this.element).exists(message);
  }
}

class FieldHelper {
  constructor(element, context, name) {
    this.element = element;
    this.name = name;
    this.context = context;
  }

  get value() {
    this.context
      .dom(this.element)
      .exists(`Could not find element (name: ${this.name}).`);

    switch (this.element.dataset.controlType) {
      case "image": {
        return this.element
          .querySelector(".form-kit__control-image a.lightbox")
          ?.getAttribute("href");
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

  isEnabled(message) {
    this.context.notOk(this.disabled, message);
  }

  hasValue(value, message) {
    this.context.deepEqual(this.value, value, message);
  }

  hasNoValue(message) {
    this.context.true(isBlank(this.value), message);
  }

  isDisabled(message) {
    this.context.ok(this.disabled, message);
  }

  get disabled() {
    this.context.dom(this.element).exists();
    return this.element.dataset.disabled === "";
  }

  hasTitle(title, message) {
    switch (this.element.dataset.controlType) {
      case "checkbox": {
        this.context
          .dom(this.element.querySelector(".form-kit__control-checkbox-title"))
          .hasText(title, message);
        break;
      }
      default: {
        this.context
          .dom(this.element.querySelector(".form-kit__container-title"))
          .hasText(title, message);
      }
    }
  }

  hasDescription(description, message) {
    switch (this.element.dataset.controlType) {
      case "checkbox": {
        this.context
          .dom(
            this.element.querySelector(
              ".form-kit__control-checkbox-description"
            )
          )
          .hasText(description, message);
        break;
      }
      default: {
        this.context
          .dom(this.element.querySelector(".form-kit__container-description"))
          .hasText(description, message);
      }
    }
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

  hasNoErrors(message) {
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
      this.context,
      name
    );
  }

  fieldset(name) {
    return new FieldsetHelper(
      query(`.form-kit__fieldset[name="${name}"]`, this.element),
      this.context,
      name
    );
  }
}

export function setupFormKitAssertions() {
  QUnit.assert.form = function (selector = "form") {
    return new FormHelper(selector, this);
  };
}
