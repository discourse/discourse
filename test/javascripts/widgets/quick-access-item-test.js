import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("quick-access-item");

const CONTENT_DIV_SELECTOR = "li > a > div";

widgetTest("content attribute is escaped", {
  template: '{{mount-widget widget="quick-access-item" args=args}}',

  beforeEach() {
    this.set("args", { content: "<b>bold</b>" });
  },

  test(assert) {
    const contentDiv = find(CONTENT_DIV_SELECTOR)[0];
    assert.equal(contentDiv.innerText, "<b>bold</b>");
  }
});

widgetTest("escapedContent attribute is not escaped", {
  template: '{{mount-widget widget="quick-access-item" args=args}}',

  beforeEach() {
    this.set("args", { escapedContent: "&quot;quote&quot;" });
  },

  test(assert) {
    const contentDiv = find(CONTENT_DIV_SELECTOR)[0];
    assert.equal(contentDiv.innerText, '"quote"');
  }
});
