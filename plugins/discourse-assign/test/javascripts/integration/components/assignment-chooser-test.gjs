import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AssignmentChooser from "discourse/plugins/discourse-assign/discourse/components/assignment-chooser";

module("Integration | Component | AssignmentChooser", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("assignmentGroups", ["category_team", "staff"]);
    this.set("assignee", null);
    this.set("onChange", () => {});
    this.set("subject", selectKit(".email-group-user-chooser"));
  });

  test("includes assignment groups missing from user search", async function (assert) {
    pretender.get("/u/search/users", () =>
      response({
        users: [{ username: "category_user" }],
        groups: [],
      })
    );

    await render(
      <template>
        <AssignmentChooser
          @value={{this.assignee}}
          @onChange={{this.onChange}}
          @options={{hash
            includeGroups=true
            assignmentGroups=this.assignmentGroups
            customSearchOptions=(hash assignableGroups=true)
          }}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.fillInFilter("category");

    assert
      .dom(".email-group-user-chooser-row[data-value='category_team']")
      .exists("the category-scoped group is included");
  });

  test("does not duplicate groups returned by user search", async function (assert) {
    pretender.get("/u/search/users", () =>
      response({
        users: [],
        groups: [{ name: "staff", full_name: "Staff" }],
      })
    );

    await render(
      <template>
        <AssignmentChooser
          @value={{this.assignee}}
          @onChange={{this.onChange}}
          @options={{hash
            includeGroups=true
            assignmentGroups=this.assignmentGroups
            customSearchOptions=(hash assignableGroups=true)
          }}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.fillInFilter("staff");

    assert
      .dom(".email-group-user-chooser-row[data-value='staff']")
      .exists({ count: 1 }, "the group appears once");
  });
});
