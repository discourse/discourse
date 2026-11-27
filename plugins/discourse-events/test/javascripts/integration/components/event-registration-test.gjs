import { getOwner } from "@ember/owner";
import { click, fillIn, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import FormDefinitionEditor from "discourse/components/form-definition-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import EventRegistration from "discourse/plugins/discourse-events/discourse/components/modal/event-registration";

module("Integration | Component | Event registration", function (hooks) {
  setupRenderingTest(hooks);

  test.each(
    "automatically registers account details for the selected occurrence and RSVP scope",
    [false, true],
    async function (assert, recurring) {
      const api = getOwner(this).lookup("service:discourse-post-event-api");
      const modal = sinon.stub(api.modal, "show");
      const join = sinon.stub(api, "joinEvent").resolves();
      const event = {
        id: 42,
        registrationForm: { builtin: "account", fields: [] },
        registrationRevision: "revision",
        isFutureOccurrence: true,
        startsAt: "2030-06-01T10:00:00Z",
      };
      assert.true(await api.rsvp(event, { status: "going", recurring }));
      assert.true(modal.notCalled);
      const [, data] = join.firstCall.args;
      assert.strictEqual(data.recurring, recurring);
      const submission = JSON.parse(data.registration);
      assert.deepEqual(submission.answers, {});
      assert.strictEqual(submission.revision, event.registrationRevision);
      assert.strictEqual(submission.occurrence, "2030-06-01T10:00:00.000Z");
      assert.ok(submission.key);
    }
  );

  test("closing registration preserves attendance for either recurring scope", async function (assert) {
    const api = getOwner(this).lookup("service:discourse-post-event-api");
    const event = {
      id: 42,
      registrationForm: { title: "Lunch", fields: [] },
      watchingInvitee: { status: "interested" },
    };
    const modal = sinon
      .stub(api.modal, "show")
      .resolves({ initiatedBy: "esc" });
    const update = sinon.stub(api, "updateEventAttendance");
    for (const recurring of [false, true]) {
      assert.false(await api.rsvp(event, { status: "going", recurring }));
    }
    assert.true(modal.calledTwice);
    assert.true(update.notCalled);
    assert.strictEqual(event.watchingInvitee.status, "interested");
  });

  test("moves field cards up and down with their edits, choices and required rules", async function (assert) {
    const initial = {
      title: "Lunch",
      fields: [
        {
          id: "meal",
          type: "dropdown",
          label: "Meal",
          required: true,
          choices: [{ id: "veg", label: "Vegetarian" }],
        },
        {
          id: "count",
          type: "number",
          label: "Guests",
          required: false,
          placeholder: "0",
        },
      ],
    };
    let saved;
    const save = (data) => {
      saved = data;
    };
    await render(
      <template>
        <FormDefinitionEditor @definition={{initial}} @onSave={{save}} />
      </template>
    );
    const card = ".form-definition-editor__question";
    const firstMenu = `${card}:first-child .form-definition-editor__field-menu`;
    const lastMenu = `${card}:last-child .form-definition-editor__field-menu`;
    const up = '[data-field-action="up"]';
    const down = '[data-field-action="down"]';
    assert
      .dom(`${card} [data-name]`)
      .hasAttribute("data-name", "fields.0.type");
    assert
      .dom('[data-name="fields.0.type"] + [data-name="fields.0.label"] label')
      .hasText("Label");
    assert
      .dom(firstMenu)
      .hasAttribute("aria-label", "Actions for Meal")
      .hasClass("btn-small", "the field actions use a small button");
    const badge = ".form-definition-editor__requirement";
    assert.dom(`${card}:first-child ${badge}`).hasText("Required");
    assert.dom(`${card}:last-child ${badge}`).hasText("Optional");
    assert.dom(`${card}[draggable="true"]`).doesNotExist();
    await fillIn('[data-name="fields.0.label"] input', "Meal preference");
    await click(firstMenu);
    assert.dom(up).isDisabled();
    await click(down);
    assert
      .dom('[data-name="fields.1.label"] input')
      .hasValue("Meal preference");
    assert.dom('[name="fields.0.placeholder"]').hasValue("0");
    assert.dom(lastMenu).isFocused();
    assert
      .dom(`${card}:last-child ${badge}`)
      .hasText("Required", "the badge moves with its field");
    await click(lastMenu);
    assert.dom(down).isDisabled();
    await click(up);
    assert
      .dom('[data-name="fields.0.label"] input')
      .hasValue("Meal preference");
    assert.dom(firstMenu).isFocused();
    await click(firstMenu);
    await click(down);
    await fillIn(
      '[data-name="fields.1.choices.0.label"] input',
      "Vegetarian meal"
    );
    await click('button[type="submit"]');
    assert.deepEqual(
      saved.fields.map((field) => field.id),
      ["count", "meal"]
    );
    assert.strictEqual(saved.fields[1].label, "Meal preference");
    assert.true(saved.fields[1].required);
    assert.deepEqual(saved.fields[1].choices, [
      { id: "veg", label: "Vegetarian meal" },
    ]);
  });

  test("keeps the Add field button labeled as fields are added and removed", async function (assert) {
    const definition = { title: "Lunch", fields: [] };
    const add = ".form-definition-editor__add";
    const question = ".form-definition-editor__question";
    await render(
      <template><FormDefinitionEditor @definition={{definition}} /></template>
    );
    assert.dom(add).hasClass("btn-default").hasText("Add field");
    await click(add);
    assert.dom(add).hasText("Add field");
    await click(add);
    assert.dom(question).exists({ count: 2 });
    assert.dom(add).hasText("Add field");
    const menu = `${question} .form-definition-editor__field-menu`;
    const remove = '[data-field-action="remove"]';
    await click(menu);
    assert.dom(remove).hasText("Delete field");
    await click(remove);
    assert.dom(menu).isFocused();
    await click(menu);
    assert.dom('[data-field-action="up"]').doesNotExist();
    await click(remove);
    assert.dom(add).isFocused();
    assert.dom(add).hasText("Add field");
  });

  test.each(
    "starts with two blank choices under one legend",
    ["dropdown", "radio", "checkboxes"],
    async function (assert, fieldType) {
      const definition = { fields: [] };
      await render(
        <template><FormDefinitionEditor @definition={{definition}} /></template>
      );
      await click(".form-definition-editor__add");
      assert.dom('[name="fields.0.placeholder"]').doesNotExist();
      await formKit().field("fields.0.type").select(fieldType);

      assert.dom("fieldset legend").exists({ count: 1 }).hasText("Choices");
      assert.dom("fieldset label").doesNotExist();
      assert.dom("fieldset input").exists({ count: 2 });
      assert
        .dom('[name="fields.0.choices.0.label"]')
        .hasAttribute("aria-label", "Choice 1")
        .hasValue("");
      assert
        .dom('[name="fields.0.choices.1.label"]')
        .hasAttribute("aria-label", "Choice 2")
        .hasValue("");
      await click(".form-definition-editor__add-choice");
      assert.dom("fieldset input").exists({ count: 3 });
    }
  );

  test("adds and removes placeholder and required attributes on an existing field", async function (assert) {
    const field = {
      id: "guests",
      label: "Guests",
      type: "number",
      required: true,
      placeholder: "How many?",
    };
    const definition = { fields: [field] };
    let saved;
    const save = (value) => {
      saved = value;
    };
    await render(
      <template>
        <FormDefinitionEditor @definition={{definition}} @onSave={{save}} />
      </template>
    );

    const menu =
      ".form-definition-editor__field-menus .form-definition-editor__attributes";
    const placeholder = '[name="fields.0.placeholder"]';
    const placeholderOption = '[data-field-attribute="placeholder"]';
    const requiredOption = '[data-field-attribute="required"]';
    const requirement = ".form-definition-editor__requirement";
    assert
      .dom(requirement)
      .hasText("Required", "the card marks the field as required")
      .hasAttribute("aria-pressed", "true")
      .hasAttribute("aria-label", "Required response for Guests");
    assert
      .dom(menu)
      .hasAttribute("aria-label", "Edit attributes for Guests")
      .hasText("Attributes")
      .hasClass("btn-small", "the attributes menu uses a small button");
    assert
      .dom(`${menu} .d-icon-chevron-down`)
      .exists("a chevron identifies the attributes dropdown");
    assert.dom(placeholder).hasValue("How many?");
    await click(requirement);
    assert
      .dom(requirement)
      .hasText("Optional")
      .hasAttribute("aria-pressed", "false");
    await click(menu);
    assert.dom(requiredOption).hasAttribute("aria-pressed", "false");
    assert.dom(placeholderOption).hasAttribute("aria-pressed", "true");
    await click(requiredOption);
    assert
      .dom(requirement)
      .hasText("Required", "the badge reflects the menu change")
      .hasAttribute("aria-pressed", "true");
    await click(menu);
    assert.dom(requiredOption).hasAttribute("aria-pressed", "true");
    await click(placeholderOption);
    assert.dom(placeholder).doesNotExist();
    await click(requirement);
    await click('button[type="submit"]');
    assert.deepEqual(saved.fields, [
      { id: "guests", label: "Guests", type: "number", required: false },
    ]);

    await click(menu);
    assert.dom(placeholderOption).hasAttribute("aria-pressed", "false");
    await click(placeholderOption);
    assert.dom(placeholder).hasValue("");
    await fillIn(placeholder, "Total guests");
    await formKit().field("fields.0.type").select("textarea");
    assert.dom(placeholder).hasValue("Total guests");
    await click('button[type="submit"]');
    assert.strictEqual(saved.fields[0].placeholder, "Total guests");
    await formKit().field("fields.0.type").select("date");
    assert.dom(placeholder).doesNotExist();
    await click(menu);
    assert.dom(placeholderOption).doesNotExist();
    assert.dom(requiredOption).exists();
  });

  test("authors a required choice question and submits its stable option ID", async function (assert) {
    const definition = { title: "Lunch", description: "", fields: [] };
    let saved;
    const save = (value) => {
      saved = value;
    };
    await render(
      <template>
        <FormDefinitionEditor
          @definition={{definition}}
          @fieldTypes={{array "dropdown"}}
          @onSave={{save}}
        />
      </template>
    );
    await click(".form-definition-editor__add");
    await fillIn('[data-name="fields.0.label"] input', "Meal");
    await fillIn('[data-name="fields.0.choices.0.label"] input', "Vegetarian");
    await fillIn('[data-name="fields.0.choices.1.label"] input', "Vegan");
    await click(".form-definition-editor__attributes");
    assert.dom('[data-field-attribute="placeholder"]').doesNotExist();
    await click('[data-field-attribute="required"]');
    await click('button[type="submit"]');
    assert.strictEqual(saved.fields[0].label, "Meal");
    let submitted;
    const model = {
      definition: saved,
      onSubmit: (value) => {
        submitted = value;
      },
    };
    const close = () => {};
    await render(
      <template>
        <EventRegistration
          @closeModal={{close}}
          @inline={{true}}
          @model={{model}}
        />
      </template>
    );
    assert
      .dom('.event-registration input[type="email"]')
      .hasValue("eviltrout@example.com")
      .hasAttribute("readonly");
    await click('button[type="submit"]');
    assert.strictEqual(submitted, undefined);
    const field = saved.fields[0];
    await formKit().field(field.id).select(field.choices[0].id);
    await click('button[type="submit"]');
    assert.deepEqual(submitted, { [field.id]: field.choices[0].id });
  });

  test("authors and reorders display text that members can read without answering", async function (assert) {
    const definition = {
      title: "Workshop",
      fields: [
        { id: "guests", type: "number", label: "Guests", required: false },
        {
          id: "note",
          type: "text",
          label: "Bring lunch.",
          required: true,
          placeholder: "Meal",
        },
      ],
    };
    let saved;
    const save = (value) => {
      saved = value;
    };
    await render(
      <template>
        <FormDefinitionEditor @definition={{definition}} @onSave={{save}} />
      </template>
    );
    const type = formKit().field("fields.1.type");
    await type.select("display_text");
    const card = ".form-definition-editor__question:last-child";
    assert.dom(`${card} .form-definition-editor__attributes`).doesNotExist();
    assert.dom(`${card} .form-definition-editor__requirement`).doesNotExist();
    assert.dom('[name="fields.1.content"]').hasValue("Bring lunch.");
    assert
      .dom(`${card} .form-definition-editor__field-menu`)
      .hasAttribute("aria-label", "Actions for Display text “Bring lunch.”");
    const firstLine = "a".repeat(254) + "🎉";
    await fillIn(
      '[name="fields.1.content"]',
      firstLine + "\nThis line is for members."
    );
    await type.select("text");
    assert.dom('[name="fields.1.label"]').hasValue("a".repeat(254));
    assert
      .dom(`${card} .form-definition-editor__requirement`)
      .hasText("Optional");
    await type.select("display_text");
    const content = "Bring lunch.\nMeet outside <b>Hall A</b>.";
    await fillIn('[name="fields.1.content"]', content);
    await click(`${card} .form-definition-editor__field-menu`);
    await click('[data-field-action="up"]');
    await click('button[type="submit"]');
    assert.deepEqual(saved.fields[0], {
      id: "note",
      type: "display_text",
      content,
    });

    const onSubmit = sinon.spy();
    const model = { definition: saved, onSubmit };
    const close = () => {};
    await render(
      <template>
        <EventRegistration
          @closeModal={{close}}
          @inline={{true}}
          @model={{model}}
        />
      </template>
    );
    const text = find(".form-definition-fields__text");
    assert.strictEqual(text.textContent.trim(), content);
    assert.dom("b", text).doesNotExist();
    assert.dom('.form-definition-fields__text + [data-name="guests"]').exists();
    assert.dom('[name="note"]').doesNotExist();
    await click('button[type="submit"]');
    assert.deepEqual(onSubmit.firstCall.args[0], {});
  });

  test("submits multiple choice IDs and requires at least one checked option", async function (assert) {
    const field = {
      id: "sessions",
      label: "Sessions",
      type: "checkboxes",
      required: true,
      choices: [
        { id: "design", label: "Design" },
        { id: "testing", label: "Testing" },
      ],
    };
    const submit = sinon.spy();
    const model = { definition: { fields: [field] }, onSubmit: submit };
    const close = () => {};
    await render(
      <template>
        <EventRegistration
          @closeModal={{close}}
          @inline={{true}}
          @model={{model}}
        />
      </template>
    );
    const design = 'input[type="checkbox"][value="design"]';
    const testing = 'input[type="checkbox"][value="testing"]';
    const submitButton = '.event-registration button[type="submit"]';
    await click(design);
    await click(design);
    await click(submitButton);
    assert.true(submit.notCalled, "clearing all choices blocks registration");
    await click(design);
    await click(testing);
    assert
      .dom(design)
      .isChecked("selecting a second choice preserves the first");
    await click(submitButton);
    assert.deepEqual(
      submit.firstCall.args[0],
      { sessions: ["design", "testing"] },
      "both selected IDs are submitted"
    );
  });
});
