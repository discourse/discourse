import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DComboButton from "discourse/ui-kit/d-combo-button";

module("Integration | ui-kit | DComboButton", function (hooks) {
  setupRenderingTest(hooks);

  async function open() {
    await triggerEvent(".fk-d-menu__trigger", "click");
  }

  test("the menu aligns with the trailing edge of its trigger by default", async function (assert) {
    await render(
      <template>
        <DComboButton class="--has-menu" as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}} @visibilityOptimizer="none">
            content
          </combo.Menu>
        </DComboButton>
      </template>
    );
    await open();

    assert.dom(".fk-d-menu").hasAttribute("data-placement", "bottom-end");
  });

  test("@placement overrides the default alignment", async function (assert) {
    await render(
      <template>
        <DComboButton class="--has-menu" as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu
            @inline={{true}}
            @visibilityOptimizer="none"
            @placement="bottom-start"
          >
            content
          </combo.Menu>
        </DComboButton>
      </template>
    );
    await open();

    assert.dom(".fk-d-menu").hasAttribute("data-placement", "bottom-start");
  });

  test("the menu trigger uses a chevron icon by default", async function (assert) {
    await render(
      <template>
        <DComboButton class="--has-menu" as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".fk-d-menu__trigger .d-icon-chevron-down").exists();
  });

  test("@icon overrides the default trigger icon", async function (assert) {
    await render(
      <template>
        <DComboButton class="--has-menu" as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}} @icon="gear">content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".fk-d-menu__trigger .d-icon-gear").exists();
    assert.dom(".fk-d-menu__trigger .d-icon-chevron-down").doesNotExist();
  });
});
