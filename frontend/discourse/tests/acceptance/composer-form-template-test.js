import {
  click,
  currentURL,
  fillIn,
  find,
  settled,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import TopicFixtures from "discourse/tests/fixtures/topic";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const FORM_TEMPLATES = [
  {
    id: 1,
    name: "Testing",
    template: `
      - type: input
        id: full-name
        attributes:
          label: "Full name"
          description: "What is your full name?"
      - type: textarea
        id: description
        attributes:
          label: "Description"
      - type: input
        id: disabled-input
        attributes:
          label: "Disabled input"
          disabled: true
    `,
  },
  {
    id: 2,
    name: "Another Test",
    template: `
      - type: input
        id: activity-date
        attributes:
          label: "Activity Date"
          placeholder: "Please select activity date"
        validations:
          required: true
          type: date
    `,
  },
  {
    id: 3,
    name: "Required Composer Only",
    template: `
      - type: composer
        id: md-description
        attributes:
          label: "Description"
        validations:
          required: true
    `,
  },
  {
    id: 4,
    name: "Required Composer With Other Field",
    template: `
      - type: input
        id: other-field
        attributes:
          label: "Other field"
      - type: composer
        id: md-description
        attributes:
          label: "Description"
        validations:
          required: true
    `,
  },
];

acceptance("Composer Form Template", function (needs) {
  needs.user({
    id: 5,
    username: "kris",
    whisperer: true,
  });
  needs.settings({
    enable_form_templates: true,
    general_category_id: 1,
    default_composer_category: 1,
  });
  needs.site({
    can_tag_topics: true,
    categories: [
      {
        id: 1,
        name: "General",
        slug: "general",
        permission: 1,
        topic_template: null,
        form_template_ids: [1, 2, 3, 4],
      },
      {
        id: 2,
        name: "test too",
        slug: "test-too",
        permission: 1,
        topic_template: "",
      },
    ],
  });
  needs.pretender((server, helper) => {
    server.put("/u/kris.json", () => helper.response({ user: {} }));

    server.get("/form-templates.json", () => {
      return helper.response({
        form_templates: FORM_TEMPLATES,
      });
    });

    [1, 2, 3, 4].forEach((id) => {
      server.get(`/form-templates/${id}.json`, () => {
        const index = id - 1;

        return helper.response({
          form_template: FORM_TEMPLATES[index],
        });
      });
    });

    server.get("/posts/419", () => {
      return helper.response({ id: 419 });
    });

    server.get("/composer/mentions", () => {
      return helper.response({
        users: [],
        user_reasons: {},
        groups: { staff: { user_count: 30 } },
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });

    server.get("/t/960.json", () => {
      const topicList = cloneJSON(TopicFixtures["/t/9/1.json"]);
      topicList.post_stream.posts[2].post_type = 4;
      return helper.response(topicList);
    });
  });

  test("Composer Form Template is shrank and reopened", async function (assert) {
    await visit("/");
    await click("#create-topic");

    assert.strictEqual(
      selectKit(".form-template-chooser").header().value(),
      "1"
    );
    assert.strictEqual(selectKit(".category-chooser").header().value(), "1");

    assert.dom("#reply-control").hasClass("open", "reply control is open");

    assert
      .dom(".form-template-field__input[name='disabled-input']")
      .isDisabled();

    await fillIn(".form-template-field__input[name='full-name']", "John Smith");

    await fillIn(
      ".form-template-field__textarea[name='description']",
      "Community manager"
    );

    await click(".toggle-minimize");

    assert
      .dom("#reply-control")
      .hasClass("draft", "reply control is minimized into draft mode");

    await click("#reply-control");

    assert
      .dom("#reply-control")
      .hasClass("open", "reply control is opened from draft mode");

    assert
      .dom(".form-template-field__input[name='full-name']")
      .hasValue(
        "John Smith",
        "keeps the value of the input field when composer is re-opened from draft mode"
      );

    assert
      .dom(".form-template-field__textarea[name='description']")
      .hasValue(
        "Community manager",
        "keeps the value of the textarea field when composer is re-opened from draft mode"
      );
  });

  test("Composer opens with the specified form template selected", async function (assert) {
    await visit("/");

    const composer = this.owner.lookup("service:composer");
    const formTemplate = FORM_TEMPLATES[1];

    await composer.openNewTopic({ formTemplate });
    await settled();

    assert.strictEqual(
      selectKit(".form-template-chooser").header().value(),
      "2"
    );
    assert
      .dom(".form-template-field__input[name='activity-date']")
      .exists("it renders form template field");
  });

  test("blocks topic creation and shows a validation message when a required composer field is left empty", async function (assert) {
    pretender.post("/posts", () => {
      assert.true(
        false,
        "a topic should not be created while the required field is empty"
      );
      return response(200, { success: true });
    });

    await visit("/");

    const composer = this.owner.lookup("service:composer");
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");

    await composer.openNewTopic({ formTemplate: FORM_TEMPLATES[2] });
    await settled();

    await fillIn("#reply-title", "A title that is long enough to be valid");
    await click("#reply-control button.create");

    assert.strictEqual(currentURL(), "/", "the topic is not created");
    assert
      .dom(".form-template-field__error")
      .exists("a validation error message is shown");

    assert
      .dom(".d-editor-input")
      .hasAttribute("aria-invalid", "true", "the editor is marked invalid");

    const describedBy =
      find(".d-editor-input").getAttribute("aria-describedby");
    assert
      .dom(`#${describedBy}`)
      .hasText(
        i18n("form_templates.errors.value_missing.default"),
        "the editor is connected to the visible error"
      );

    assert.true(
      announce.calledWith(
        i18n("form_templates.errors.value_missing.default"),
        "assertive"
      ),
      "the error is announced to screen readers"
    );

    await fillIn(".d-editor-input", "some content");

    assert
      .dom(".d-editor-input")
      .doesNotHaveAttribute("aria-invalid", "the invalid state is cleared");
    assert
      .dom(".d-editor-input")
      .doesNotHaveAttribute(
        "aria-describedby",
        "the error reference is cleared"
      );
  });

  test("keeps the editor marked invalid after switching editor modes", async function (assert) {
    await visit("/");

    const composer = this.owner.lookup("service:composer");
    await composer.openNewTopic({ formTemplate: FORM_TEMPLATES[2] });
    await settled();

    await fillIn("#reply-title", "A title that is long enough to be valid");
    await click("#reply-control button.create");

    assert
      .dom(".d-editor-input")
      .hasAttribute("aria-invalid", "true", "the editor starts out invalid");

    assert
      .dom(".d-editor-input")
      .hasAttribute("aria-required", "true", "the editor starts out required");

    await click(".composer-toggle-switch");

    assert
      .dom(".d-editor-input")
      .hasAttribute(
        "aria-required",
        "true",
        "the replacement editor is still marked required"
      );

    assert
      .dom(".d-editor-input")
      .hasAttribute(
        "aria-invalid",
        "true",
        "the replacement editor is still marked invalid"
      );

    const describedBy =
      find(".d-editor-input").getAttribute("aria-describedby");
    assert
      .dom(`#${describedBy}`)
      .hasText(
        i18n("form_templates.errors.value_missing.default"),
        "the replacement editor is still connected to the visible error"
      );
  });

  test("preserves newlines from a composer field in the generated post body", async function (assert) {
    let capturedRaw;
    pretender.post("/posts", (request) => {
      capturedRaw = parsePostData(request.requestBody).raw;
      return response(200, {
        success: true,
        action: "create_post",
        post: { id: 42, topic_id: 960, topic_slug: "x" },
      });
    });

    await visit("/");

    const composer = this.owner.lookup("service:composer");
    await composer.openNewTopic({ formTemplate: FORM_TEMPLATES[2] });
    await settled();

    const multiline = "## Heading\n\nParagraph one.\n\n- item a\n- item b";
    await fillIn("#reply-title", "A title that is long enough to be valid");
    await fillIn(".d-editor-input", multiline);
    await click("#reply-control button.create");

    // normalise CRLF (from FormData's textarea handling) to LF so the
    // assertions describe the shape, not the transport encoding
    const raw = capturedRaw.replace(/\r\n/g, "\n");

    assert.true(
      raw.includes("## Heading\n\nParagraph one."),
      "the multi-line composer field survives to the submitted post body"
    );
    assert.true(
      raw.includes("- item a\n- item b"),
      "list items from the composer field reach the post body on separate lines"
    );
  });

  test("blocks topic creation when a required composer field is empty even if other fields are filled", async function (assert) {
    pretender.post("/posts", () => {
      assert.true(
        false,
        "a topic should not be created while the required field is empty"
      );
      return response(200, { success: true });
    });

    await visit("/");

    const composer = this.owner.lookup("service:composer");
    await composer.openNewTopic({ formTemplate: FORM_TEMPLATES[3] });
    await settled();

    await fillIn("#reply-title", "A title that is long enough to be valid");
    await fillIn(
      ".form-template-field__input[name='other-field']",
      "some content"
    );
    await click("#reply-control button.create");

    assert.strictEqual(currentURL(), "/", "the topic is not created");
    assert
      .dom(".form-template-field__error")
      .exists("a validation error message is shown");
  });
});
