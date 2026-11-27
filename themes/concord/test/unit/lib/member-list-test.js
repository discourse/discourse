import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import MemberList from "../../../discourse/lib/member-list.js";

const alice = { id: 1, username: "alice" };
const bob = { id: 2, username: "bob" };
const carol = { id: 3, username: "carol" };
const dave = { id: 4, username: "dave" };

// The sorting, without the requests: members, who's online and the roles are
// given rather than fetched.
class TestMemberList extends MemberList {
  members = [];
  online = [];
  testRoles = [];

  get pager() {
    return { users: this.members };
  }

  get onlineUsers() {
    return this.online;
  }

  get roles() {
    return this.testRoles;
  }
}

module("Unit | Lib | member-list", function (hooks) {
  setupTest(hooks);

  // The admins role's members, for the one request the list makes itself.
  hooks.beforeEach(function () {
    pretender.get("/groups/admins/members.json", () =>
      response(200, { members: [bob, dave], owners: [] })
    );
  });

  function memberList(owner, current) {
    return new TestMemberList(owner, { value: current });
  }

  function summary(list) {
    return list.sections.map((section) => [
      section.id,
      section.users.map((user) => user.username),
    ]);
  }

  test("roles first, then everyone else online, then offline", function (assert) {
    const list = memberList(getOwner(this), { type: "forum" });
    list.members = [alice, bob, carol, dave];
    list.online = [alice, bob, carol];
    list.testRoles = [{ name: "admins", full_name: "Admins" }];
    list.roleMembers = new Map([["admins", new Set([bob.id, dave.id])]]);

    assert.deepEqual(summary(list), [
      ["role-admins", ["bob"]],
      ["online", ["alice", "carol"]],
      ["offline", ["dave"]],
    ]);
  });

  test("a private chat channel lists only its own members", function (assert) {
    const list = memberList(getOwner(this), {
      type: "text",
      channel: { id: 9, chatable: { read_restricted: true } },
    });
    list.members = [alice, bob];
    list.online = [alice, carol];

    assert.deepEqual(summary(list), [
      ["online", ["alice"]],
      ["offline", ["bob"]],
    ]);
  });

  test("a public chat channel lists everyone online", function (assert) {
    const list = memberList(getOwner(this), {
      type: "text",
      channel: { id: 9, chatable: { read_restricted: false } },
    });
    list.members = [alice, bob];
    list.online = [alice, carol];

    assert.deepEqual(summary(list), [
      ["online", ["alice", "carol"]],
      ["offline", ["bob"]],
    ]);
  });

  test("a voice channel has no member list", function (assert) {
    const list = memberList(getOwner(this), {
      type: "voice",
      room: { name: "Campfire" },
    });

    assert.false(list.available);
    assert.false(list.active);
  });

  test("empty sections are left out", function (assert) {
    const list = memberList(getOwner(this), { type: "forum" });
    list.members = [alice];
    list.testRoles = [{ name: "admins" }];

    assert.deepEqual(summary(list), [["offline", ["alice"]]]);
  });
});
