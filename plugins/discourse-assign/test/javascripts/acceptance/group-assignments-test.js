import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import GroupFixtures from "discourse/tests/fixtures/group-fixtures";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import AssignedTopics from "../fixtures/assigned-group-assignments-fixtures";
import GroupMembers from "../fixtures/group-members-fixtures";

let canSeeMembers = true;

acceptance("GroupAssignments", function (needs) {
  needs.user();
  needs.settings({ assign_enabled: true, assigns_user_url_path: "/" });
  needs.hooks.beforeEach(() => {
    canSeeMembers = true;
  });
  needs.pretender((server, helper) => {
    const groupPath = "/topics/group-topics-assigned/discourse.json";
    const memberPath = "/topics/messages-assigned/ahmedgagan6.json";
    const getMembersPath = "/assign/members/discourse";
    const groupAssigns = AssignedTopics[groupPath];
    const memberAssigns = AssignedTopics[memberPath];
    const getMembers = GroupMembers[getMembersPath];
    server.get("/groups/discourse.json", () => {
      const response = cloneJSON(GroupFixtures["/groups/discourse.json"]);
      response.group.can_show_assigned_tab = true;
      response.group.can_see_members = canSeeMembers;
      return helper.response(response);
    });
    server.get(groupPath, () => helper.response(groupAssigns));
    server.get(memberPath, () => helper.response(memberAssigns));
    server.get(getMembersPath, () => helper.response(getMembers));
  });

  test("Group Assignments Everyone", async function (assert) {
    await visit("/g/discourse/assigned");
    assert.dom(".topic-list-item").exists({ count: 1 });
  });

  test("Group Assignments Ahmedgagan", async function (assert) {
    await visit("/g/discourse/assigned/ahmedgagan6");
    assert.dom(".topic-list-item").exists({ count: 1 });
  });

  test("does not show the Assignments tab when group members are hidden", async function (assert) {
    updateCurrentUser({ can_assign: true, can_assign_globally: true });
    canSeeMembers = false;

    await visit("/g/discourse");

    assert.dom(".assigned-topic-list").doesNotExist();
  });
});
