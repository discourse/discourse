import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import User from "discourse/models/user";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import chatDecorators from "discourse/plugins/chat/discourse/initializers/chat-decorators";

function decoratedLinks() {
  const origin = window.location.origin;
  const element = document.createElement("div");
  element.innerHTML = `
    <a class="external" href="https://example.com/thing">external</a>
    <a class="in-prefix" href="${origin}/forum/t/topic/1">in prefix</a>
    <a class="out-of-prefix" href="${origin}/item/thing">out of prefix</a>
  `;
  chatDecorators.decorateLinkTargets(element);
  return element;
}

module("Discourse Chat | Unit | chat-decorators | links", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn(this.owner);
    setPrefix("/forum");
  });

  test("keeps every link in the same tab by default", function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", false);
    const element = decoratedLinks();

    assert.dom(".external", element).doesNotHaveAttribute("target");
    assert.dom(".external", element).doesNotHaveClass("raw-link");
    assert.dom(".in-prefix", element).doesNotHaveAttribute("target");
    assert.dom(".in-prefix", element).doesNotHaveClass("raw-link");
    assert.dom(".out-of-prefix", element).doesNotHaveAttribute("target");
    assert.dom(".out-of-prefix", element).hasClass("raw-link");
  });

  test("opens links outside the forum in a new tab when the user opts in", function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);
    const element = decoratedLinks();

    assert.dom(".external", element).hasAttribute("target", "_blank");
    assert.dom(".in-prefix", element).doesNotHaveAttribute("target");
    assert.dom(".out-of-prefix", element).hasAttribute("target", "_blank");
  });
});
