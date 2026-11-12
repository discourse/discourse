import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import GroupFixtures from "discourse/tests/fixtures/group-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import GroupAssignments from "../fixtures/assigned-group-assignments-fixtures.js";
import AssignedTopics from "../fixtures/assigned-topics-fixtures.js";
import GroupMembers from "../fixtures/group-members-fixtures.js";

const QueueFilterProbe = <template>
  <div class="queue-filter-probe">filter</div>
</template>;

// stands in for a plugin's filter control registered through the outlet
function renderProbe() {
  withPluginApi((api) => {
    api.renderInOutlet("before-assigned-topic-list", QueueFilterProbe);
  });
}

acceptance(
  "Discourse Assign | user queue outlet stays rendered when the filtered list is empty",
  function (needs) {
    needs.user();
    needs.settings({ assign_enabled: true, assigns_user_url_path: "/" });
    needs.pretender((server, helper) => {
      const assignments = cloneJSON(
        AssignedTopics["/topics/messages-assigned/eviltrout.json"]
      );
      assignments.topic_list.topics = [];
      server.get("/topics/messages-assigned/eviltrout.json", () =>
        helper.response(assignments)
      );
    });

    test("the outlet renders next to the empty state", async function (assert) {
      renderProbe();
      await visit("/u/eviltrout/activity/assigned");

      assert.dom("div.empty-state").exists();
      assert.dom(".queue-filter-probe").exists();
    });
  }
);

acceptance(
  "Discourse Assign | group queue outlet stays rendered when the filtered list is empty",
  function (needs) {
    needs.user();
    needs.settings({ assign_enabled: true, assigns_user_url_path: "/" });
    needs.pretender((server, helper) => {
      server.get("/groups/discourse.json", () => {
        const response = cloneJSON(GroupFixtures["/groups/discourse.json"]);
        response.group.can_show_assigned_tab = true;
        return helper.response(response);
      });

      const groupPath = "/topics/group-topics-assigned/discourse.json";
      const groupAssigns = cloneJSON(GroupAssignments[groupPath]);
      groupAssigns.topic_list.topics = [];
      server.get(groupPath, () => helper.response(groupAssigns));

      server.get("/assign/members/discourse", () =>
        helper.response(GroupMembers["/assign/members/discourse"])
      );
    });

    test("the outlet renders next to the empty state", async function (assert) {
      renderProbe();
      await visit("/g/discourse/assigned/everyone");

      assert.dom("div.empty-state").exists();
      assert.dom(".queue-filter-probe").exists();
    });
  }
);
