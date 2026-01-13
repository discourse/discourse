import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - policy plugin extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.policy_enabled = true;
    });

    test("policy with multiple groups", async function (assert) {
      const markdown = `[policy groups="staff,admins" version="2"]\nI accept the terms\n\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).hasAttribute("data-groups", "staff,admins");
      assert.dom(policyElement).hasAttribute("data-version", "2");
      assert.dom("p", policyElement).hasText("I accept the terms");

      assert.strictEqual(value, markdown);
    });

    test("policy with all attributes", async function (assert) {
      const markdown = `[policy group="staff" version="1" accept="true" revoke="false" reminder="daily" renew-start="2023-01-01" private="true"]\nComplex policy\n\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).hasAttribute("data-group", "staff");
      assert.dom(policyElement).hasAttribute("data-version", "1");
      assert.dom(policyElement).hasAttribute("data-accept", "true");
      assert.dom(policyElement).hasAttribute("data-revoke", "false");
      assert.dom(policyElement).hasAttribute("data-reminder", "daily");
      assert.dom(policyElement).hasAttribute("data-renew-start", "2023-01-01");
      assert.dom(policyElement).hasAttribute("data-private", "true");
      assert.dom("p", policyElement).hasText("Complex policy");

      assert.strictEqual(value, markdown);
    });

    test("policy with content around", async function (assert) {
      const markdown = `Hello world\n\n[policy group="everyone" version="1"]\nI accept\n\n[/policy]\n\nGoodbye world`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).hasAttribute("data-group", "everyone");
      assert.dom("p", policyElement).hasText("I accept");

      assert.strictEqual(value, markdown);
    });

    test("empty policy", async function (assert) {
      const markdown = `[policy group="staff" version="1"]\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).hasAttribute("data-group", "staff");
      assert.dom(policyElement).hasAttribute("data-version", "1");
      assert.dom("p", policyElement).doesNotExist();

      assert.strictEqual(value, markdown);
    });

    test("policy with multiline content", async function (assert) {
      const markdown = `[policy group="staff" version="1"]\nFirst line\n\nSecond paragraph\n\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom("p", policyElement).exists({ count: 2 });
      assert.dom("p:first-child", policyElement).hasText("First line");
      assert.dom("p:last-child", policyElement).hasText("Second paragraph");

      assert.strictEqual(value, markdown);
    });

    test("policy filters out empty attributes", async function (assert) {
      const inputMarkdown = `[policy group="staff" version="1" accept="" revoke=""]\nTest\n[/policy]`;
      const expectedMarkdown = `[policy group="staff" version="1"]\nTest\n\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, inputMarkdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).hasAttribute("data-group", "staff");
      assert.dom(policyElement).hasAttribute("data-version", "1");
      assert.dom(policyElement).doesNotHaveAttribute("data-accept");
      assert.dom(policyElement).doesNotHaveAttribute("data-revoke");
      assert.dom("p", policyElement).hasText("Test");

      assert.strictEqual(value, expectedMarkdown);
    });

    test("policy renders basic structure in rich editor", async function (assert) {
      const markdown = `[policy group="staff" version="1"]\nI accept this policy\n\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).exists();
      assert.dom(policyElement).hasClass("policy");
      assert.dom(policyElement).hasAttribute("data-group", "staff");
      assert.dom(policyElement).hasAttribute("data-version", "1");

      // Check that content is preserved
      assert.dom("p", policyElement).hasText("I accept this policy");

      assert.strictEqual(value, markdown);
    });

    test("policy handles empty content", async function (assert) {
      const markdown = `[policy groups="admins" version="2"]\n[/policy]\n\n`;
      const [{ value }] = await setupRichEditor(assert, markdown);

      const policyElement = document.querySelector(".ProseMirror .policy");
      assert.dom(policyElement).exists();
      assert.dom(policyElement).hasAttribute("data-groups", "admins");
      assert.dom(policyElement).hasAttribute("data-version", "2");

      assert.strictEqual(value, markdown);
    });
  }
);
