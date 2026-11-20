import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import FormDefinitionEditor from "discourse/components/form-definition-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { moveViaChord } from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
import EventRegistration from "discourse/plugins/discourse-events/discourse/components/modal/event-registration";

module("Integration | Component | Event registration", function (hooks) {
  setupRenderingTest(hooks);

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

  test("keeps field IDs and required rules when reordering", async function (assert) {
    const initial = {
      title: "Lunch",
      fields: [
        { id: "meal", type: "text", label: "Meal", required: true },
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
    await moveViaChord("count", "up");
    await fillIn('[data-name="fields.1.label"] input', "Meal preference");
    await click('button[type="submit"]');
    assert.deepEqual(
      saved.fields.map((field) => field.id),
      ["count", "meal"]
    );
    assert.strictEqual(saved.fields[1].label, "Meal preference");
    assert.true(saved.fields[1].required);
  });

  test("authors a required choice question and submits its stable option ID", async function (assert) {
    const definition = { title: "Lunch", description: "", fields: [] };
    let saved;
    const save = (value) => {
      saved = value;
    };
    await render(
      <template>
        <FormDefinitionEditor @definition={{definition}} @onSave={{save}} />
      </template>
    );
    await click(".form-definition-editor__add");
    await fillIn('[data-name="fields.0.label"] input', "Meal");
    await formKit().field("fields.0.type").select("dropdown");
    await fillIn('[data-name="fields.0.choices.0.label"] input', "Vegetarian");
    await click('[data-name="fields.0.required"] input');
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
    await click('button[type="submit"]');
    assert.strictEqual(submitted, undefined);
    const field = saved.fields[0];
    await formKit().field(field.id).select(field.choices[0].id);
    await click('button[type="submit"]');
    assert.strictEqual(submitted[field.id], field.choices[0].id);
  });
});
