import QUnit from "qunit";
import { query } from "discourse/tests/helpers/qunit-helpers";

class DSelect {
  constructor(selector, context) {
    this.context = context;
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = query(selector);
    }
  }

  hasOption(value, assertionMessage) {
    this.context
      .dom(this.element.querySelector(`.d-select__option[value="${value}"]`))
      .exists(assertionMessage);
  }

  hasNoOption(value, assertionMessage) {
    this.context
      .dom(this.element.querySelector(`.d-select__option[value="${value}"]`))
      .doesNotExist(assertionMessage);
  }
}

export function setupDSelectAssertions() {
  QUnit.assert.dselect = function (selector = ".d-select") {
    return new DSelect(selector, this);
  };
}
