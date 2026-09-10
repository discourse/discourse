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
    currentUser.set("user_option.chat_channel_list_filter_starred", "active");
    currentUser.set("user_option.chat_channel_list_filter_dms", "unread");
    currentUser.set("user_option.chat_channel_list_sort", "priority");
    currentUser.set(
      "user_option.chat_channel_list_sort_starred",
      "recent_activity"
    );
    currentUser.set("user_option.chat_channel_list_sort_dms", "priority");

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.strictEqual(
      preferences.filterFor("channels"),
      CHAT_CHANNEL_LIST_FILTERS.MENTIONS,
      "it initializes the channels filter"
    );
    assert.strictEqual(
      preferences.filterFor("starred"),
      CHAT_CHANNEL_LIST_FILTERS.ACTIVE,
      "it initializes the starred filter"
    );
    assert.strictEqual(
      preferences.filterFor("dms"),
      CHAT_CHANNEL_LIST_FILTERS.UNREAD,
      "it initializes the dms filter"
    );
    assert.strictEqual(
      preferences.sortFor("channels"),
      CHAT_CHANNEL_LIST_SORTS.PRIORITY,
      "it initializes the channels sort"
    );
    assert.strictEqual(
      preferences.sortFor("starred"),
      CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY,
      "it initializes the starred sort"
    );
    assert.strictEqual(
      preferences.sortFor("dms"),
      CHAT_CHANNEL_LIST_SORTS.PRIORITY,
      "it initializes the dms sort"
    );
  });

  test("uses defaults without a signed-in user", async function (assert) {
    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.strictEqual(
      preferences.filterFor("channels"),
      "all",
      "the channels filter defaults to all"
    );
    assert.strictEqual(
      preferences.filterFor("starred"),
      "all",
      "the starred filter defaults to all"
    );
    assert.strictEqual(
      preferences.filterFor("dms"),
      "all",
      "the dms filter defaults to all"
    );
    assert.strictEqual(
      preferences.sortFor("channels"),
      "alphabetical",
      "the channels sort defaults to alphabetical"
    );
    assert.strictEqual(
      preferences.sortFor("starred"),
      "alphabetical",
      "the starred sort defaults to alphabetical"
    );
    assert.strictEqual(
      preferences.sortFor("dms"),
      "alphabetical",
      "the dms sort defaults to alphabetical"
    );
    assert.false(
      await preferences.setFilter("channels", CHAT_CHANNEL_LIST_FILTERS.UNREAD),
      "anonymous filter changes are refused"
    );
    assert.false(
      await preferences.setSort("channels", CHAT_CHANNEL_LIST_SORTS.PRIORITY),
      "anonymous sort changes are refused"
    );
  });

  test("saves filter and sort changes per section independently", async function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "all");
    currentUser.set("user_option.chat_channel_list_sort", "alphabetical");
    currentUser.set(
      "user_option.chat_channel_list_sort_starred",
      "alphabetical"
    );
    currentUser.set("user_option.chat_channel_list_sort_dms", "alphabetical");
    const pendingSaves = [];
    currentUser.save = (fields) =>
      new Promise((resolve) => {
        pendingSaves.push({ fields, resolve });
      });

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );
    const channelsFilterSave = preferences.setFilter(
      "channels",
      CHAT_CHANNEL_LIST_FILTERS.UNREAD
    );
    const dmsFilterSave = preferences.setFilter(
      "dms",
      CHAT_CHANNEL_LIST_FILTERS.MENTIONS
    );
    const channelsSave = preferences.setSort(
      "channels",
      CHAT_CHANNEL_LIST_SORTS.PRIORITY
    );
    const starredSave = preferences.setSort(
      "starred",
      CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY
    );

    assert.strictEqual(
      preferences.filterFor("channels"),
      "unread",
      "the channels filter is optimistic"
    );
    assert.strictEqual(
      preferences.filterFor("dms"),
      "mentions",
      "the dms filter is optimistic"
    );
    assert.strictEqual(
      preferences.filterFor("starred"),
      "all",
      "the starred filter is untouched"
    );
    assert.strictEqual(
      preferences.sortFor("channels"),
      "priority",
      "the channels sort is optimistic"
    );
    assert.strictEqual(
      preferences.sortFor("starred"),
      "recent_activity",
      "the starred sort is optimistic"
    );
    assert.strictEqual(
      preferences.sortFor("dms"),
      "alphabetical",
      "the dms sort is untouched"
    );
    assert.true(
      preferences.isSavingFilterFor("channels"),
      "channels filter is saving"
    );
    assert.true(preferences.isSavingFilterFor("dms"), "dms filter is saving");
    assert.false(
      preferences.isSavingFilterFor("starred"),
      "starred filter is not saving"
    );
    assert.true(
      preferences.isSavingSortFor("channels"),
      "channels sort is saving"
    );
    assert.true(
      preferences.isSavingSortFor("starred"),
      "starred sort is saving"
    );
    assert.false(preferences.isSavingSortFor("dms"), "dms sort is not saving");
    assert.deepEqual(
      pendingSaves.map(({ fields }) => fields),
      [
        ["chat_channel_list_filter"],
        ["chat_channel_list_filter_dms"],
        ["chat_channel_list_sort"],
        ["chat_channel_list_sort_starred"],
      ],
      "each preference saves without blocking the others"
    );

    pendingSaves.forEach(({ resolve }) => resolve());
    assert.true(await channelsFilterSave, "the channels filter completes");
    assert.true(await dmsFilterSave, "the dms filter completes");
    assert.true(await channelsSave, "the channels sort completes");
    assert.true(await starredSave, "the starred sort completes");
    ["channels", "starred", "dms"].forEach((section) => {
      assert.false(
        preferences.isSavingFilterFor(section),
        `the ${section} filter pending state clears`
      );
      assert.false(
        preferences.isSavingSortFor(section),
        `the ${section} sort pending state clears`
      );
    });
  });

  test("persists changed preferences", async function (assert) {
    const currentUser = logIn(this.owner);
    currentUser.set("user_option.chat_channel_list_filter", "all");
    currentUser.set("user_option.chat_channel_list_filter_dms", "all");
    currentUser.set("user_option.chat_channel_list_sort", "alphabetical");
    currentUser.set("user_option.chat_channel_list_sort_dms", "alphabetical");
    const requests = [];
    pretender.put("/u/eviltrout.json", (request) => {
      requests.push(new URLSearchParams(request.requestBody));
      return response(200, { user: {} });
    });

    const preferences = getOwner(this).lookup(
      "service:chat-channel-list-preferences"
    );

    assert.true(
      await preferences.setFilter("channels", CHAT_CHANNEL_LIST_FILTERS.UNREAD),
      "the channels filter saves"
    );
    assert.true(
      await preferences.setFilter("dms", CHAT_CHANNEL_LIST_FILTERS.MENTIONS),
      "the dms filter saves"
    );
    assert.true(
      await preferences.setSort(
        "channels",
        CHAT_CHANNEL_LIST_SORTS.RECENT_ACTIVITY
      ),
      "the channels sort saves"
    );
    assert.true(
      await preferences.setSort("dms", CHAT_CHANNEL_LIST_SORTS.PRIORITY),
      "the dms sort saves"
    );

    assert.strictEqual(requests.length, 4, "each changed preference is saved");
    assert.strictEqual(
      requests[0].get("chat_channel_list_filter"),
      "unread",
      "only the changed channels filter is sent"
    );
    assert.strictEqual(
      requests[0].get("chat_channel_list_sort"),
      null,
      "the sort is omitted from the filter request"
    );
    assert.strictEqual(
      requests[1].get("chat_channel_list_filter_dms"),
      "mentions",
      "only the changed dms filter is sent"
    );
    assert.strictEqual(
      requests[1].get("chat_channel_list_filter"),
      null,
      "the channels filter is omitted"
    );
    assert.strictEqual(
      requests[2].get("chat_channel_list_sort"),
      "recent_activity",
      "only the changed channels sort is sent"
    );
    assert.strictEqual(
      requests[2].get("chat_channel_list_filter"),
      null,
      "the filter is omitted from the sort request"
    );
    assert.strictEqual(
      requests[3].get("chat_channel_list_sort_dms"),
      "priority",
      "only the changed dms sort is sent"
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
      await preferences.setFilter("channels", CHAT_CHANNEL_LIST_FILTERS.ALL),
      "an unchanged value succeeds"
    );
    assert.false(
      await preferences.setFilter("channels", "invalid"),
      "an invalid value fails"
    );
    assert.true(
      await preferences.setSort(
        "channels",
        CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL
      ),
      "an unchanged sort succeeds"
    );
    assert.false(
      await preferences.setSort("channels", "invalid"),
      "an invalid sort fails"
    );
    assert.false(
      await preferences.setFilter(
        "unknown-section",
        CHAT_CHANNEL_LIST_FILTERS.UNREAD
      ),
      "an unknown section fails"
    );
    assert.false(
      await preferences.setSort(
        "unknown-section",
        CHAT_CHANNEL_LIST_SORTS.PRIORITY
      ),
      "an unknown sort section fails"
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
      await preferences.setFilter("channels", CHAT_CHANNEL_LIST_FILTERS.UNREAD),
      "the failed request is reported"
    );
    assert.strictEqual(
      preferences.filterFor("channels"),
      "all",
      "the service value is restored"
    );
    assert.strictEqual(
      currentUser.user_option.chat_channel_list_filter,
      "all",
      "the user option is restored"
    );
    assert.false(
      preferences.isSavingFilterFor("channels"),
      "the saving state is cleared"
    );
  });
});
