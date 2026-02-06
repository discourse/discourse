import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DDefaultToast from "discourse/float-kit/components/d-default-toast";
import DToastInstance from "discourse/float-kit/lib/d-toast-instance";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function buildToast(context, options = {}) {
  return new DToastInstance(getOwner(context), options);
}

module("Integration | Component | FloatKit | DDefaultToast", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.close = () => {};
    this.isFront = true;
    this.onProgressComplete = () => {};
    this.progressBarStyle = "";
  });

  test("icon", async function (assert) {
    this.toast = buildToast(this, { data: { icon: "check" } });

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert
      .dom(".fk-d-default-toast__icon .d-icon-check")
      .exists("it renders the configured icon");
  });

  test("no icon", async function (assert) {
    this.toast = buildToast(this);

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert
      .dom(".fk-d-default-toast__icon")
      .doesNotExist("it omits the icon container");
  });

  test("progress bar", async function (assert) {
    this.toast = buildToast(this, {
      autoClose: true,
      showProgressBar: true,
    });

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert
      .dom(".fk-d-default-toast__progress-wrapper")
      .exists("it renders the visible progress wrapper");
    assert
      .dom(".fk-d-default-toast__progress-bar")
      .exists("it renders the progress bar");
  });

  test("no progress bar", async function (assert) {
    this.toast = buildToast(this, {
      autoClose: false,
      showProgressBar: true,
    });

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert
      .dom(".fk-d-default-toast__progress-bar")
      .doesNotExist("it omits progress when auto close is disabled");
  });

  test("title", async function (assert) {
    this.toast = buildToast(this, { data: { title: "Title" } });

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert.dom(".fk-d-default-toast__title").hasText("Title");
  });

  test("no title", async function (assert) {
    this.toast = buildToast(this);

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert
      .dom(".fk-d-default-toast__title")
      .doesNotExist("it omits the title");
  });

  test("message", async function (assert) {
    this.toast = buildToast(this, { data: { message: "Message" } });

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert.dom(".fk-d-default-toast__description").hasText("Message");
  });

  test("no message", async function (assert) {
    this.toast = buildToast(this);

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert
      .dom(".fk-d-default-toast__description")
      .doesNotExist("it omits the description");
  });

  test("action", async function (assert) {
    this.action = () => assert.step("action");
    this.toast = buildToast(this, {
      data: {
        action: {
          label: "Ok",
          onClick: this.action,
        },
      },
    });

    await render(
      <template>
        <DDefaultToast
          @toast={{this.toast}}
          @close={{this.close}}
          @isFront={{this.isFront}}
          @progressBarStyle={{this.progressBarStyle}}
          @onProgressComplete={{this.onProgressComplete}}
        />
      </template>
    );

    assert.dom(".fk-d-default-toast__action-btn").exists().hasText("Ok");

    await click(".fk-d-default-toast__action-btn");

    assert.verifySteps(["action"]);
  });
});
