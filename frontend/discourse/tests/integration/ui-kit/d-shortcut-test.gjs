import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DShortcut from "discourse/ui-kit/d-shortcut";
import { i18n } from "discourse-i18n";

module("Integration | ui-kit | DShortcut", function (hooks) {
  setupRenderingTest(hooks);

  test("draws one keycap per key inside a combination", async function (assert) {
    sinon.stub(capabilities, "isApple").value(false);

    await render(<template><DShortcut @keys="mod+shift+b" /></template>);

    assert
      .dom("kbd.d-shortcut")
      .exists({ count: 1 })
      .hasAttribute("dir", "ltr")
      .doesNotHaveAttribute("aria-hidden", "readable when it is the content");
    assert.dom(".d-shortcut > kbd.d-shortcut__key").exists({ count: 3 });
    assert
      .dom(".d-shortcut__key:nth-child(1)")
      .hasText(i18n("shortcut_modifier_key.ctrl"));
    assert.dom(".d-shortcut__key:nth-child(3)").hasText("B");
  });

  test("gives a glyph a visually hidden spoken name", async function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    await render(<template><DShortcut @keys="mod+b" /></template>);

    const command = document.querySelector(".d-shortcut__key:nth-child(1)");
    assert.dom(command).hasClass("d-shortcut__key--glyph");
    assert.dom("[aria-hidden='true']", command).hasText("⌘");
    assert
      .dom(".sr-only", command)
      .hasText(i18n("shortcut_modifier_key.command"));

    const letter = document.querySelector(".d-shortcut__key:nth-child(2)");
    assert.dom(letter).doesNotHaveClass("d-shortcut__key--glyph");
    assert.dom(".sr-only", letter).doesNotExist();
    assert.dom(letter).hasText("B");
  });

  test("forwards attributes to the combination element", async function (assert) {
    await render(
      <template>
        <DShortcut class="my-hint" data-test-hint="yes" @keys="mod+k" />
      </template>
    );

    assert.dom("kbd.d-shortcut.my-hint").hasAttribute("data-test-hint", "yes");
  });

  test("shows nothing without a physical keyboard, unless told to always", async function (assert) {
    sinon.stub(capabilities, "hasKeyboard").get(() => false);

    await render(
      <template>
        <DShortcut @keys="mod+k" class="gated" />
        <DShortcut @keys="mod+k" @always={{true}} class="documented" />
        <DShortcut @keys="mod+enter" as |shortcut|>
          <button type="button" aria-keyshortcuts={{shortcut.aria}}>
            Save
            <shortcut.Kbd />
          </button>
        </DShortcut>
      </template>
    );

    assert.dom("kbd.gated").doesNotExist();
    assert.dom("kbd.documented .d-shortcut__key").exists({ count: 2 });
    assert.dom("button").doesNotHaveAttribute("aria-keyshortcuts");
    assert.dom("button kbd").doesNotExist();
  });

  test("renders nothing without keys", async function (assert) {
    await render(<template><DShortcut /></template>);

    assert.dom("kbd").doesNotExist();
  });

  test("yields both forms and a bound keycap component to a block", async function (assert) {
    sinon.stub(capabilities, "isApple").value(true);

    await render(
      <template>
        <DShortcut @keys="mod+enter" as |shortcut|>
          <button
            type="button"
            aria-keyshortcuts={{shortcut.aria}}
            data-label={{shortcut.label}}
          >
            Save
            <shortcut.Kbd class="inside" />
          </button>
        </DShortcut>
      </template>
    );

    assert.dom("button").hasAttribute("aria-keyshortcuts", "Command+Enter");
    assert
      .dom("button > kbd.d-shortcut")
      .hasAttribute("aria-hidden", "true", "the activator announces it");
    assert
      .dom("button")
      .hasAttribute("data-label", `⌘ ${i18n("shortcut_modifier_key.enter")}`);
    assert.dom("button > kbd.d-shortcut.inside").exists({ count: 1 });
    assert.dom("button > kbd .d-shortcut__key").exists({ count: 2 });
    assert.dom("kbd").exists({ count: 3 }, "no wrapper element of its own");
  });

  test("yields an undefined announcement and an empty keycap without keys", async function (assert) {
    await render(
      <template>
        <DShortcut as |shortcut|>
          <button type="button" aria-keyshortcuts={{shortcut.aria}}>
            Save
            <shortcut.Kbd />
          </button>
        </DShortcut>
      </template>
    );

    assert.dom("button").doesNotHaveAttribute("aria-keyshortcuts");
    assert.dom("kbd").doesNotExist();
  });
});
