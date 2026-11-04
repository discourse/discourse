import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import User from "discourse/models/user";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import chatDecorators from "discourse/plugins/chat/discourse/initializers/chat-decorators";

function decoratedLinks() {
  // Chat decorates messages in a detached document, like this one.
  const element = document.implementation
    .createHTMLDocument("detached")
    .createElement("div");
  element.innerHTML = `
    <a class="external" href="https://example.com/thing">external</a>
    <a class="in-prefix" href="/sub/t/topic/1">in prefix</a>
    <a class="out-of-prefix" href="/item/thing">out of prefix</a>
    <a class="root" href="/">root</a>
    <a class="absolute-root" href="${window.location.origin}/">absolute root</a>
    <a class="explicit-new-tab" href="/" target="_blank">explicit new tab</a>
  `;
  chatDecorators.decorateLinkTargets(element);
  return element;
}

module("Discourse Chat | Unit | chat-decorators | links", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    setPrefix("/sub");
  });

  test("keeps subfolder links in the same tab with the preference disabled", function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", false);
    const element = decoratedLinks();

    assert.dom(".external", element).hasAttribute("target", "_blank");
    assert.dom(".external", element).doesNotHaveClass("raw-link");
    assert.dom(".in-prefix", element).doesNotHaveAttribute("target");
    assert.dom(".in-prefix", element).doesNotHaveClass("raw-link");

    for (const selector of [".out-of-prefix", ".root", ".absolute-root"]) {
      assert.dom(selector, element).doesNotHaveAttribute("target");
      assert.dom(selector, element).hasClass("raw-link");
    }

    assert.dom(".explicit-new-tab", element).hasAttribute("target", "_blank");
  });

  test("keeps subfolder links in the same tab with the preference enabled", function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);
    const element = decoratedLinks();

    assert.dom(".external", element).hasAttribute("target", "_blank");
    assert.dom(".external", element).doesNotHaveClass("raw-link");
    assert.dom(".in-prefix", element).doesNotHaveAttribute("target");
    assert.dom(".in-prefix", element).doesNotHaveClass("raw-link");

    for (const selector of [".out-of-prefix", ".root", ".absolute-root"]) {
      assert.dom(selector, element).doesNotHaveAttribute("target");
      assert.dom(selector, element).hasClass("raw-link");
    }

    assert.dom(".explicit-new-tab", element).hasAttribute("target", "_blank");
  });
});
