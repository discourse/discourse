import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import TopicAssignments from "discourse/plugins/discourse-assign/discourse/components/topic-assignments";

module("Integration | Component | TopicAssignments", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.assign_enabled = true;
    this.siteSettings.assign_allow_multiple_topic_assignees = true;
    pretender.get("/assign/suggestions", () =>
      response({ suggestions: [], groups: [] })
    );
  });

  test("edits one note and removes one assignee without changing the other", async function (assert) {
    this.siteSettings.enable_assign_status = true;
    this.siteSettings.assign_statuses = "New|In progress|Done";
    const data = {
      can_add_multiple: true,
      active_post_assignments: 0,
      max_assignments: 20,
      assignments: [
        {
          id: 1,
          username: "martin",
          note: "Check the references",
          showNote: false,
          status: "New",
        },
        {
          id: 2,
          username: "sam",
          note: "Check the publication",
          showNote: false,
        },
      ],
    };
    const api = {};
    let saved;
    const submit = (draft) => {
      saved = draft;
    };

    await render(
      <template>
        <TopicAssignments
          @collectionData={{data}}
          @formApi={{api}}
          @onSubmit={{submit}}
          @topicId={{44}}
        />
      </template>
    );
    assert
      .dom(".topic-assignments-editor__row")
      .exists({ count: 2 }, "both assignees are shown");
    await click(
      ".topic-assignments-editor__row:first-child .topic-assignments-editor__note-action"
    );
    await formKit().field("assignments.0.note").fillIn("Updated references");
    await formKit().field("assignments.0.status").select("In progress");
    await click(
      '.topic-assignments-editor__row:last-child button[title="Remove @sam from assignments"]'
    );
    await api.submit();

    assert.strictEqual(
      saved.assignments.length,
      1,
      "only the selected assignee is removed"
    );
    assert.strictEqual(
      saved.assignments[0].id,
      1,
      "the retained assignment keeps its identity"
    );
    assert.strictEqual(
      saved.assignments[0].note,
      "Updated references",
      "the retained note is edited"
    );
    assert.strictEqual(
      saved.assignments[0].status,
      "In progress",
      "each assignee has their own status"
    );
    assert.strictEqual(
      data.assignments[0].note,
      "Check the references",
      "draft edits do not mutate the original"
    );
  });

  test("adds a group alongside a user and rejects a second group", async function (assert) {
    pretender.get("/assign/search", () =>
      response({
        users: [],
        groups: [{ name: "editors" }, { name: "reviewers" }],
      })
    );
    const data = {
      can_add_multiple: true,
      active_post_assignments: 0,
      max_assignments: 20,
      assignments: [{ id: 1, username: "martin", note: "" }],
    };
    const api = {};
    let saved;
    const submit = (draft) => {
      saved = draft;
    };
    await render(
      <template>
        <TopicAssignments
          @collectionData={{data}}
          @formApi={{api}}
          @onSubmit={{submit}}
          @topicId={{44}}
        />
      </template>
    );
    const chooser = selectKit(".email-group-user-chooser");
    await chooser.expand();
    await chooser.fillInFilter("editor");
    await chooser.selectRowByValue("editors");
    assert
      .dom(".topic-assignments-editor__row")
      .exists({ count: 2 }, "a group can accompany a user");
    await chooser.expand();
    await chooser.fillInFilter("review");
    await chooser.selectRowByValue("reviewers");
    assert
      .dom(".topic-assignments-editor__row")
      .exists({ count: 2 }, "a second group is rejected");
    assert
      .form()
      .hasErrors(
        { assignee: "Only one group can be assigned to a topic." },
        "the group restriction is explained"
      );
    assert.strictEqual(
      saved,
      undefined,
      "the invalid draft has not been submitted"
    );
  });
});
