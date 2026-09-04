import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import {
  CHAT_CHANNEL_LIST_FILTERS,
  CHAT_CHANNEL_LIST_SORTS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";

module("Unit | Service | chat-channel-list-preferences", function (hooks) {
  setupTest(hooks);

  test("initializes from the current user", function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "mentions");
    currentUser.set("user_option.chat_channel_list_sort", "priority");

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.strictEqual(
      preferences.filter,
      CHAT_CHANNEL_LIST_FILTERS.MENTIONS,
      "it initializes the filter"
    );
    assert.strictEqual(
      preferences.sort,
      CHAT_CHANNEL_LIST_SORTS.PRIORITY,
      "it initializes the sort"
    );
  });

  test("uses defaults without a signed-in user", async function (assert) {
    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.strictEqual(preferences.filter, "all", "the filter defaults to all");
    assert.strictEqual(
      preferences.sort,
      "alphabetical",
      "the sort defaults to alphabetical"
    );
    assert.false(
      await preferences.setFilter(CHAT_CHANNEL_LIST_FILTERS.UNREAD),
      "anonymous changes are refused"
    );
  });

  test("saves filter and sort changes independently", async function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "all");
    currentUser.set("user_option.chat_channel_list_sort", "alphabetical");
    const pendingSaves = [];
    currentUser.save = (fields) =>
      new Promise((resolve) => {
        pendingSaves.push({ fields, resolve });
      });

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    const filterSave = preferences.setFilter(CHAT_CHANNEL_LIST_FILTERS.UNREAD);
    const sortSave = preferences.setSort(CHAT_CHANNEL_LIST_SORTS.PRIORITY);

    assert.strictEqual(
      preferences.filter,
      "unread",
      "the filter is optimistic"
    );
    assert.strictEqual(preferences.sort, "priority", "the sort is optimistic");
    assert.true(preferences.isSavingFilter, "the filter save is pending");
    assert.true(preferences.isSavingSort, "the sort save is pending");
    assert.deepEqual(
      pendingSaves.map(({ fields }) => fields),
      [["chat_channel_list_filter"], ["chat_channel_list_sort"]],
      "each preference saves without blocking the other"
    );

    pendingSaves.forEach(({ resolve }) => resolve());
    assert.true(await filterSave, "the filter change completes");
    assert.true(await sortSave, "the sort change completes");
    assert.false(preferences.isSaving, "the combined pending state clears");
  });

  test("persists changed preferences", async function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "all");
    currentUser.set("user_option.chat_channel_list_sort", "alphabetical");
    const requests = [];
    pretender.put("/u/eviltrout.json", (request) => {
      requests.push(new URLSearchParams(request.requestBody));
      return response(200, { user: {} });
    });

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.true(
      await preferences.setFilter(CHAT_CHANNEL_LIST_FILTERS.UNREAD),
      "the filter saves"
    );
    assert.true(
      await preferences.setSort(CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY),
      "the sort saves"
    );

    assert.strictEqual(requests.length, 2, "each changed preference is saved");
    assert.strictEqual(
      requests[0].get("chat_channel_list_filter"),
      "unread",
      "only the changed filter is sent"
    );
    assert.strictEqual(
      requests[0].get("chat_channel_list_sort"),
      null,
      "the sort is omitted from the filter request"
    );
    assert.strictEqual(
      requests[1].get("chat_channel_list_sort"),
      "recent_activity",
      "only the changed sort is sent"
    );
  });

  test("does not save unchanged or invalid values", async function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "all");
    let requestsCount = 0;
    pretender.put("/u/eviltrout.json", () => {
      requestsCount += 1;
      return response(200, { user: {} });
    });

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.true(
      await preferences.setFilter(CHAT_CHANNEL_LIST_FILTERS.ALL),
      "an unchanged value succeeds"
    );
    assert.false(
      await preferences.setFilter("invalid"),
      "an invalid value fails"
    );
    assert.strictEqual(requestsCount, 0, "no request is sent");
  });

  test("rolls back a failed save", async function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "all");
    pretender.put("/u/eviltrout.json", () => {
      return response(422, { errors: ["Unable to save"] });
    });

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.false(
      await preferences.setFilter(CHAT_CHANNEL_LIST_FILTERS.UNREAD),
      "the failed request is reported"
    );
    assert.strictEqual(
      preferences.filter,
      "all",
      "the service value is restored"
    );
    assert.strictEqual(
      currentUser.user_option.chat_channel_list_filter,
      "all",
      "the user option is restored"
    );
    assert.false(preferences.isSaving, "the saving state is cleared");
  });
});
