import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";
import WorkflowsForm from "discourse/plugins/discourse-workflows/discourse/components/workflows-form";

module("Integration | Component | WorkflowsForm", function (hooks) {
  setupRenderingTest(hooks);

  test("renders backend form schema with FormKit controls", async function (assert) {
    this.set("model", {
      form_title: "Intake",
      data: {
        name: "",
        age: "",
        bio: "",
        email: "",
        password: "",
        starts_on: "",
        plan: "basic",
        contact_method: "",
      },
      fields: [
        {
          name: "name",
          title: "Name",
          type: "input",
          validation: "required",
          placeholder: "Your name",
        },
        {
          name: "age",
          title: "Age",
          type: "input-number",
        },
        {
          name: "bio",
          title: "Bio",
          type: "textarea",
          placeholder: "Tell us more",
        },
        {
          name: "email",
          title: "Email",
          type: "input-email",
        },
        {
          name: "password",
          title: "Password",
          type: "password",
        },
        {
          name: "starts_on",
          title: "Starts on",
          type: "input-date",
        },
        {
          name: "plan",
          title: "Plan",
          type: "select",
          options: [
            { value: "basic", label: "Basic" },
            { value: "pro", label: "Pro" },
          ],
        },
        {
          name: "contact_method",
          title: "Contact method",
          type: "radio-group",
          options: [
            { value: "email", label: "Email" },
            { value: "phone", label: "Phone" },
          ],
        },
        {
          name: "intro",
          title: "Intro",
          type: "html",
          html: "<strong>Escaped intro</strong>",
        },
      ],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);

    assert.dom(".workflows-form__title").hasText("Intake");
    assert.dom('[data-name="name"]').hasClass("form-kit__field-input");
    assert.dom('input[name="name"]').hasAttribute("placeholder", "Your name");
    assert.dom('[data-name="age"]').hasClass("form-kit__field-input-number");
    assert.dom('input[name="age"]').hasAttribute("type", "number");
    assert
      .dom('textarea[name="bio"]')
      .hasAttribute("placeholder", "Tell us more");
    assert.dom('input[name="email"]').hasAttribute("type", "email");
    assert.dom('input[name="password"]').hasAttribute("type", "password");
    assert.dom('input[name="starts_on"]').hasAttribute("type", "date");
    assert.dom('select[name="plan"]').exists();
    assert.dom('option[value="basic"]').hasText("Basic");
    assert.dom('option[value="pro"]').hasText("Pro");
    assert.dom('input[name="contact_method"][value="email"]').exists();
    assert.dom('input[name="contact_method"][value="phone"]').exists();
    assert.dom(".workflows-form__html strong").hasText("Escaped intro");
    assert.dom(".workflows-form__html").doesNotIncludeText("<strong>");
    assert.dom('input[name="tracking_id"]').doesNotExist();
  });

  test("autofocuses the first field", async function (assert) {
    this.set("model", {
      data: { name: "", email: "" },
      fields: [
        { name: "name", title: "Name", type: "input" },
        { name: "email", title: "Email", type: "input-email" },
      ],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);

    assert.dom('input[name="name"]').isFocused();
  });

  test("renders the test mode banner", async function (assert) {
    this.set("model", {
      form_mode: "test",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);

    assert
      .dom(".workflows-form__test-banner")
      .hasText(i18n("discourse_workflows.form.test_mode_banner"));
  });

  test("renders completion text HTML returned by the workflow", async function (assert) {
    pretender.post(
      "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      () =>
        response(200, {
          status: "success",
          form_completion: {
            on_submission: "show_text",
            completion_text: "<strong>Saved</strong>",
          },
        })
    );

    this.set("model", {
      form_title: "Intake",
      form_submit_url:
        "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);
    await formKit().submit();

    assert.dom(".workflows-form__completion-text strong").hasText("Saved");
    assert
      .dom(".workflows-form__completion-text")
      .doesNotIncludeText("<strong>");
  });

  test("renders workflow errors returned by submit", async function (assert) {
    pretender.post(
      "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      () =>
        response(500, {
          status: "error",
          errors: ["Error in workflow"],
        })
    );

    this.set("model", {
      form_title: "Intake",
      form_submit_url:
        "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);
    await formKit().submit();

    assert.dom(".workflows-form__error").hasText("Error in workflow");
  });

  test("renders structured validation errors returned by submit", async function (assert) {
    pretender.post(
      "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      () =>
        response(422, {
          errors: [
            { field_label: "Name", code: "missing" },
            { field_label: "Email", code: "invalid_value" },
          ],
        })
    );

    this.set("model", {
      form_title: "Intake",
      form_submit_url:
        "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);
    await formKit().submit();

    assert
      .dom(".workflows-form__error")
      .hasText("Name is required, Email is invalid");
  });

  test("renders generic error when submit returns no errors", async function (assert) {
    pretender.post(
      "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      () =>
        response(500, {
          status: "error",
        })
    );

    this.set("model", {
      form_title: "Intake",
      form_submit_url:
        "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);
    await formKit().submit();

    assert
      .dom(".workflows-form__error")
      .hasText(i18n("discourse_workflows.form.error_message"));
  });

  test("renders waiting form load errors returned from errors", async function (assert) {
    pretender.post(
      "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      () =>
        response(200, {
          form_waiting_url: "/workflows/forms/waiting/1.json",
        })
    );
    pretender.get("/workflows/forms/waiting/1.json", () =>
      response(404, {
        errors: ["Waiting form not found"],
      })
    );

    this.set("model", {
      form_title: "Intake",
      form_submit_url:
        "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);
    await formKit().submit();
    await settled();

    assert.dom(".workflows-form__error").hasText("Waiting form not found");
  });

  test("completes empty successful workflow_finishes submissions", async function (assert) {
    pretender.post(
      "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      () => [200, {}, ""]
    );

    this.set("model", {
      form_title: "Intake",
      form_submit_url:
        "/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789.json",
      data: {},
      fields: [],
    });

    await render(<template><WorkflowsForm @model={{this.model}} /></template>);
    await formKit().submit();

    assert
      .dom(".workflows-form__complete")
      .hasText(i18n("discourse_workflows.form.thank_you"));
  });
});
