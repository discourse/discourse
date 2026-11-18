import { on } from "@ember/modifier";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import User from "discourse/models/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import DHtmlWithLinks from "discourse/ui-kit/d-html-with-links";

/** Keeps the test page from following the link when the component lets it through. */
const stayOnPage = (event) => event.preventDefault();

module("Integration | ui-kit | DHtmlWithLinks", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // The new-tab preference is read from `User.current()`, which a rendering test leaves unset.
    logIn(this.owner);
    this.open = sinon.stub(window, "open").returns({ focus() {} });
  });

  test("renders its block with attributes", async function (assert) {
    await render(
      <template>
        <DHtmlWithLinks class="description">
          <p class="text">Hello</p>
        </DHtmlWithLinks>
      </template>
    );

    assert.dom(".description .text").hasText("Hello", "the block is rendered");
  });

  test("opens an external link in a new tab when the user prefers it", async function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);

    await render(
      <template>
        <DHtmlWithLinks>
          <a href="https://example.com/page" {{on "click" stayOnPage}}>link</a>
        </DHtmlWithLinks>
      </template>
    );
    await click("a");

    assert.true(
      this.open.calledOnceWith("https://example.com/page", "_blank"),
      "the link opens in a new tab"
    );
  });

  test("leaves the link alone when the user does not prefer new tabs", async function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", false);

    await render(
      <template>
        <DHtmlWithLinks>
          <a href="https://example.com/page" {{on "click" stayOnPage}}>link</a>
        </DHtmlWithLinks>
      </template>
    );
    await click("a");

    assert.false(this.open.called, "no new tab is opened");
  });

  test("ignores clicks outside links", async function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);

    await render(
      <template>
        <DHtmlWithLinks>
          <span class="plain" data-href="https://example.com/page">text</span>
        </DHtmlWithLinks>
      </template>
    );
    await click(".plain");

    assert.false(this.open.called, "no new tab is opened");
  });
});
