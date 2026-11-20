import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import { fixture } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | codeblock-buttons", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({
      writeText: this.writeText,
    }));
    this.buttons = new CodeblockButtons({ showFullscreen: false });
  });

  hooks.afterEach(function () {
    this.buttons.cleanup();
  });

  test("the AI badge shares the copy and expand controls' scrollbar offset", function (assert) {
    this.buttons = new CodeblockButtons({ site: { desktopView: true } });
    const container = fixture();
    const pre = document.createElement("pre");
    pre.dataset.codeAi = "true";
    const badge = document.createElement("span");
    badge.className = "ai-badge";
    const code = document.createElement("code");
    code.textContent = "const answer = 42;";
    pre.append(badge, code);
    container.appendChild(pre);

    this.buttons.attachToGeneric(container);

    const controls = pre.querySelector(".codeblock-button-wrapper");
    assert.dom(".copy-cmd", controls).exists("the row has a copy control");
    assert
      .dom(".fullscreen-cmd", controls)
      .exists("the row has an expand control");
    assert.strictEqual(
      controls.lastElementChild,
      badge,
      "the badge is at the end of the row"
    );
    assert.strictEqual(
      controls.style.insetInlineEnd,
      `${code.offsetWidth - code.clientWidth}px`,
      "the full row is offset from the scrollbar"
    );
  });

  for (const attachment of ["post", "generic"]) {
    test(`copying a ${attachment} code block preserves whitespace`, async function (assert) {
      const text =
        "    GPU0    GPU1\nGPU0    X       NV12\n\tGPU1    NV12    X  \n";
      const container = fixture();
      const pre = document.createElement("pre");
      const code = document.createElement("code");
      code.textContent = text;
      pre.appendChild(code);
      container.appendChild(pre);

      if (attachment === "post") {
        this.buttons.attachToPost({ id: 1 }, container);
      } else {
        this.buttons.attachToGeneric(container);
      }

      container.querySelector(".copy-cmd").click();
      await Promise.resolve();

      assert.true(
        this.writeText.calledOnceWithExactly(text),
        "the clipboard receives the leading indentation, tabs, trailing spaces, and final newline"
      );
    });
  }
});
