import { tracked } from "@glimmer/tracking";
import { render, rerender, triggerEvent } from "@ember/test-helpers";
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
        <DComboButton @hasMenu={{true}} as |combo|>
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
        <DComboButton @hasMenu={{true}} as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu
            @inline={{true}}
            @placement="bottom-start"
            @visibilityOptimizer="none"
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
        <DComboButton @hasMenu={{true}} as |combo|>
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
        <DComboButton @hasMenu={{true}} as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @icon="gear" @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".fk-d-menu__trigger .d-icon-gear").exists();
    assert.dom(".fk-d-menu__trigger .d-icon-chevron-down").doesNotExist();
  });

  test("@hasMenu publishes --has-menu and renders the menu", async function (assert) {
    await render(
      <template>
        <DComboButton @hasMenu={{true}} as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".d-combo-button").hasClass("--has-menu");
    assert.dom(".d-combo-button-menu").exists();
  });

  test("without @hasMenu neither the class nor the menu is rendered", async function (assert) {
    await render(
      <template>
        <DComboButton as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".d-combo-button").doesNotHaveClass("--has-menu");
    assert.dom(".d-combo-button-menu").doesNotExist();
    assert
      .dom(".d-combo-button-button")
      .exists("the button half still renders");
  });

  test("toggling @hasMenu moves the class and the menu together", async function (assert) {
    const state = new (class {
      @tracked hasMenu = false;
    })();

    await render(
      <template>
        <DComboButton @hasMenu={{state.hasMenu}} as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".d-combo-button").doesNotHaveClass("--has-menu");
    assert.dom(".d-combo-button-menu").doesNotExist();

    state.hasMenu = true;
    await rerender();

    assert.dom(".d-combo-button").hasClass("--has-menu");
    assert.dom(".d-combo-button-menu").exists();

    state.hasMenu = false;
    await rerender();

    assert.dom(".d-combo-button").doesNotHaveClass("--has-menu");
    assert.dom(".d-combo-button-menu").doesNotExist();
  });

  test("@btnTypeClass reaches both halves", async function (assert) {
    await render(
      <template>
        <DComboButton @btnTypeClass="btn-default" @hasMenu={{true}} as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".d-combo-button-button").hasClass("btn-default");
    assert.dom(".d-combo-button-menu").hasClass("btn-default");
  });

  test("a per-half class is kept alongside @btnTypeClass", async function (assert) {
    await render(
      <template>
        <DComboButton @btnTypeClass="btn-default" @hasMenu={{true}} as |combo|>
          <combo.Button class="dismiss-read" @translatedLabel="Action" />
          <combo.Menu class="dismiss-menu" @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".d-combo-button-button").hasClass("btn-default");
    assert.dom(".d-combo-button-button").hasClass("dismiss-read");
    assert.dom(".d-combo-button-menu").hasClass("btn-default");
    assert.dom(".d-combo-button-menu").hasClass("dismiss-menu");
  });

  test("--has-menu survives a consumer's dynamic class changing", async function (assert) {
    const state = new (class {
      @tracked extra = "first";
    })();

    await render(
      <template>
        <DComboButton class={{state.extra}} @hasMenu={{true}} as |combo|>
          <combo.Button @translatedLabel="Action" />
          <combo.Menu @inline={{true}}>content</combo.Menu>
        </DComboButton>
      </template>
    );

    assert.dom(".d-combo-button").hasClass("--has-menu");
    assert.dom(".d-combo-button").hasClass("first");

    state.extra = "second";
    await rerender();

    assert
      .dom(".d-combo-button")
      .hasClass("--has-menu", "the group's own token is not dropped");
    assert.dom(".d-combo-button").hasClass("second");
    assert.dom(".d-combo-button").doesNotHaveClass("first");
  });
});
