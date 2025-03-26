import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import noop from "discourse/helpers/noop";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DDefaultToast from "float-kit/components/d-default-toast";
import DToastInstance from "float-kit/lib/d-toast-instance";

module(
  "Integration | Component | FloatKit | d-default-toast",
  function (hooks) {
    setupRenderingTest(hooks);

    test("icon", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, { data: { icon: "check" } });

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert.dom(".fk-d-default-toast__icon-container .d-icon-check").exists();
    });

    test("no icon", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, {});

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert.dom(".fk-d-default-toast__icon-container").doesNotExist();
    });

    test("progress bar", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, {});

      await render(
        <template>
          <DDefaultToast
            @data={{self.toast.options.data}}
            @showProgressBar={{true}}
            @onRegisterProgressBar={{(noop)}}
          />
        </template>
      );

      assert.dom(".fk-d-default-toast__progress-bar").exists();
    });

    test("no progress bar", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, {});

      await render(
        <template>
          <DDefaultToast
            @data={{self.toast.options.data}}
            @showProgressBar={{false}}
          />
        </template>
      );

      assert.dom(".fk-d-default-toast__progress-bar").doesNotExist();
    });

    test("title", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, { data: { title: "Title" } });

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert
        .dom(".fk-d-default-toast__title")
        .hasText(this.toast.options.data.title);
    });

    test("no title", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, {});

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert.dom(".fk-d-default-toast__title").doesNotExist();
    });

    test("message", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, { data: { message: "Message" } });

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert
        .dom(".fk-d-default-toast__message")
        .hasText(this.toast.options.data.message);
    });

    test("no message", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, {});

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert.dom(".fk-d-default-toast__message").doesNotExist();
    });

    test("actions", async function (assert) {
      const self = this;

      this.toast = new DToastInstance(this, {
        data: {
          actions: [
            {
              label: "cancel",
              icon: "xmark",
              class: "btn-danger",
              action: () => {},
            },
          ],
        },
      });

      await render(
        <template><DDefaultToast @data={{self.toast.options.data}} /></template>
      );

      assert
        .dom(".fk-d-default-toast__actions .btn.btn-danger")
        .exists()
        .hasText("cancel");
    });
  }
);
