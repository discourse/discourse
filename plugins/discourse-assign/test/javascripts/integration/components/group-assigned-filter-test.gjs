import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import GroupAssignedFilter from "discourse/plugins/discourse-assign/discourse/components/group-assigned-filter";

module(
  "Discourse Assign | Integration | Component | group-assigned-filter",
  function (hooks) {
    setupRenderingTest(hooks);

    test("displays username and name", async function (assert) {
      const filter = {
        id: 2,
        username: "Ahmed",
        name: "Ahmed Gagan",
        avatar_template: "/letter_avatar_proxy/v4/letter/a/8c91f0/{size}.png",
        title: "trust_level_0",
        last_posted_at: "2020-06-22T10:15:54.532Z",
        last_seen_at: "2020-07-07T11:55:59.437Z",
        added_at: "2020-06-22T09:55:31.692Z",
        timezone: "Asia/Calcutta",
      };

      await render(
        <template>
          <GroupAssignedFilter @showAvatar={{true}} @filter={{filter}} />
        </template>
      );

      assert.dom(".assign-username").hasText("Ahmed");
      assert.dom(".assign-name").hasText("Ahmed Gagan");
    });
  }
);
