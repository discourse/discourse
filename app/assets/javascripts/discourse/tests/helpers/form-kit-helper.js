import { click, fillIn, triggerEvent } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class Field {
  constructor(selector) {
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  get controlType() {
    return this.element.dataset.controlType;
  }

  /**
   * For elements that have a single input element, this returns that element.
   *
   * @throws {Error} If the control type does not have a single input element.
   * @returns {HTMLElement} The input element for the control.
   */
  get inputElement() {
    switch (this.controlType) {
      case "input-text":
      case "input-number":
      case "password":
      case "checkbox":
        return this.element.querySelector("input");
      case "code":
      case "textarea":
      case "composer":
        return this.element.querySelector("textarea");
      case "toggle":
        return this.element.querySelector("button");
      case "select":
        return this.element.querySelector("select");
      default:
        throw new Error(`Unsupported control type: ${this.controlType}`);
    }
  }

  value() {
    switch (this.controlType) {
      case "input-text":
        return parseInt(this.inputElement.value, 10);
    }
  }

  options() {
    if (this.controlType !== "select") {
      throw new Error(`Unsupported control type: ${this.controlType}`);
    }
    return [...this.element.querySelectorAll("select option")].map((node) =>
      node.getAttribute("value")
    );
  }

  async fillIn(value) {
    await fillIn(this.inputElement, value);
  }

  async toggle() {
    switch (this.controlType) {
      case "password":
        await click(
          this.element.querySelector(".form-kit__control-password-toggle")
        );
        break;
      case "checkbox":
        await click(this.inputElement);
        break;
      case "toggle":
        await click(this.inputElement);
        break;
      default:
        throw new Error(`Unsupported control type: ${this.controlType}`);
    }
  }

  async accept() {
    if (this.controlType !== "question") {
      throw new Error(`Unsupported control type: ${this.controlType}`);
    }

    await click(
      this.element.querySelector(".form-kit__control-radio[value='true']")
    );
  }

  async refuse() {
    if (this.controlType !== "question") {
      throw new Error(`Unsupported control type: ${this.controlType}`);
    }

    await click(
      this.element.querySelector(".form-kit__control-radio[value='false']")
    );
  }

  async setDay(day) {
    if (this.controlType !== "calendar") {
      throw new Error(`Unsupported control type: ${this.controlType}`);
    }

    await click(
      this.element.querySelector(`.pika-day[data-pika-day="${day}"]`)
    );
  }

  async setTime(time) {
    if (this.controlType !== "calendar") {
      throw new Error(`Unsupported control type: ${this.controlType}`);
    }

    await fillIn(this.element.querySelector("input[type='time']"), time);
  }

  async select(value) {
    switch (this.element.dataset.controlType) {
      case "icon":
        const picker = selectKit(
          "#" + this.element.querySelector("details").id
        );
        await picker.expand();
        await picker.selectRowByValue(value);
        break;
      case "select":
        this.inputElement.value = value;
        await triggerEvent(this.inputElement, "input");
        break;
      case "menu":
        const trigger = this.element.querySelector(
          ".fk-d-menu__trigger.form-kit__control-menu-trigger"
        );
        await click(trigger);
        const menu = document.body.querySelector(
          `[aria-labelledby="${trigger.id}"`
        );
        const item = menu.querySelector(
          `.form-kit__control-menu-item[data-value="${value}"] .btn`
        );
        await click(item);
        break;
      case "radio-group":
        const radio = this.element.querySelector(
          `input[type="radio"][value="${value}"]`
        );
        await click(radio);
        break;
      default:
        throw new Error("Unsupported field type");
    }
  }

  /**
   * Triggers any event on the input element of the field.
   *
   * @param {string} eventName - The name of the event to trigger.
   * @param {Object} [options={}] - Additional options for the event.
   */
  async triggerEvent(eventName, options = {}) {
    await triggerEvent(this.inputElement, eventName, options);
  }
}

class Form {
  constructor(selector) {
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  async submit() {
    await triggerEvent(this.element, "submit");
  }

  async reset() {
    await triggerEvent(this.element, "reset");
  }

  field(name) {
    const fieldElement = this.element.querySelector(`[data-name="${name}"]`);

    if (!fieldElement) {
      throw new Error(`Field with name ${name} not found`);
    }

    return new Field(fieldElement);
  }

  hasField(name) {
    return !!this.element.querySelector(`[data-name="${name}"]`);
  }
}

export default function form(selector = "form") {
  const helper = new Form(selector);

  return {
    async submit() {
      await helper.submit();
    },
    async reset() {
      await helper.reset();
    },
    field(name) {
      return helper.field(name);
    },

    hasField(name) {
      return helper.hasField(name);
    },
  };
}
