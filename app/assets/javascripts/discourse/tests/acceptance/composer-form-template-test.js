import { click, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { toggleCheckDraftPopup } from "discourse/services/composer";
import TopicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

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
];

acceptance("Composer Form Template", function (needs) {
  needs.user({
    id: 5,
    username: "kris",
    whisperer: true,
  });
  needs.settings({
    experimental_form_templates: true,
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
        form_template_ids: [1, 2],
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

    [1, 2].forEach((id) => {
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

  needs.hooks.afterEach(() => toggleCheckDraftPopup(false));

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

    await click(".toggle-fullscreen");

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
});
