import { fn } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";

module(
  "Integration | Component | FormKit | Controls | Image",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.post("/uploads.json", () =>
        response({
          extension: "jpeg",
          filesize: 126177,
          height: 800,
          human_filesize: "123 KB",
          id: 202,
          original_filename: "avatar.PNG.jpg",
          retain_hours: null,
          short_path: "/uploads/short-url/yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
          short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
          thumbnail_height: 320,
          thumbnail_width: 690,
          url: "/images/discourse-logo-sketch-small.png",
          width: 1920,
        })
      );
    });

    test("default", async function (assert) {
      let data = { image_url: "/images/discourse-logo-sketch-small.png" };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @name="image_url" @title="Foo" as |field|>
              <field.Image @type="site_setting" />
            </form.Field>
          </Form>
        </template>
      );

      await formKit().submit();

      assert.form().field("image_url").hasValue(data.image_url);
    });

    test("removing the upload", async function (assert) {
      let data = { image_url: "/images/discourse-logo-sketch-small.png" };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field @name="image_url" @title="Foo" as |field|>
              <field.Image @type="site_setting" />
            </form.Field>

            <form.Button
              class="test"
              @action={{fn form.set "image_url" null}}
            />
          </Form>
        </template>
      );

      await formKit().submit();

      assert.form().field("image_url").hasValue(data.image_url);

      await click(".test");

      assert.form().field("image_url").hasNoValue();
    });

    test("when disabled", async function (assert) {
      const data = { image_url: "/images/discourse-logo-sketch-small.png" };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <form.Field
              @name="image_url"
              @title="Foo"
              @disabled={{true}}
              as |field|
            >
              <field.Image @type="site_setting" />
            </form.Field>
          </Form>
        </template>
      );

      assert.dom(".image-upload-controls input[type='file']").isDisabled();
      assert.dom(".image-upload-controls .btn-danger").isDisabled();
    });
  }
);
