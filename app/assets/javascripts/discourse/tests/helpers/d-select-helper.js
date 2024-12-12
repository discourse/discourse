import { triggerEvent } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";

class Select {
  constructor(selector) {
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  async selectOption(value) {
    this.element.value = value;
    await triggerEvent(this.element, "input");
  }
}

export default function form(selector = ".d-select") {
  const helper = new Select(selector);

  return {
    async selectOption(value) {
      await helper.selectOption(value);
    },
  };
}
