import { find } from "@ember/test-helpers";
import QUnit from "qunit";

class DNativeSelect {
  constructor(selector, context) {
    this.context = context;
    if (selector instanceof HTMLElement) {
      this.element = selector;
    } else {
      this.element = find(selector);
    }
  }

  hasOption({ value, label }, assertionMessage) {
    const option = this.element.querySelector(
      `.d-native-select__option[value="${value}"]`
    );

    this.context.dom(option).exists(assertionMessage);
    this.context.dom(option).hasText(label, assertionMessage);

    return this;
  }

  hasNoOption(value, assertionMessage) {
    const option = this.element.querySelector(
      `.d-native-select__option[value="${value}"]`
    );

    this.context.dom(option).doesNotExist(assertionMessage);

    return this;
  }

  hasSelectedOption({ value, label }, assertionMessage) {
    this.context
      .dom(this.element.options[this.element.selectedIndex])
      .hasText(label, assertionMessage);

    this.context.dom(this.element).hasValue(value, assertionMessage);

    return this;
  }

  hasNoSelectedOption({ value, label }, assertionMessage) {
    this.context
      .dom(this.element.options[this.element.selectedIndex])
      .hasNoText(label, assertionMessage);

    this.context.dom(this.element).hasNoValue(value, assertionMessage);

    return this;
  }
}

export function setupDNativeSelectAssertions() {
  QUnit.assert.dnativeselect = function (selector = ".d-native-select") {
    return new DNativeSelect(selector, this);
  };
}
