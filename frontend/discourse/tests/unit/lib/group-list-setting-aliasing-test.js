import { module, test } from "qunit";
import {
  mapEveryoneToLoggedInUsersIds,
  mapLoggedInUsersToEveryoneForStorage,
} from "discourse/lib/group-list-setting-aliasing";

module("Unit | Lib | group-list-setting-aliasing", function () {
  test("mapEveryoneToLoggedInUsersIds is an identity when granular permissions are disabled", function (assert) {
    assert.deepEqual(mapEveryoneToLoggedInUsersIds(["0", "11"], false), [
      "0",
      "11",
    ]);
  });

  test("mapEveryoneToLoggedInUsersIds normalizes numeric ids to strings", function (assert) {
    assert.deepEqual(mapEveryoneToLoggedInUsersIds([1, 2], true), ["1", "2"]);
  });

  test("mapEveryoneToLoggedInUsersIds swaps everyone for logged_in_users", function (assert) {
    assert.deepEqual(mapEveryoneToLoggedInUsersIds(["0", "11"], true), [
      "5",
      "11",
    ]);
  });

  test("mapEveryoneToLoggedInUsersIds dedupes when both everyone and logged_in_users are present", function (assert) {
    assert.deepEqual(mapEveryoneToLoggedInUsersIds(["0", "5", "11"], true), [
      "5",
      "11",
    ]);
  });

  test("mapLoggedInUsersToEveryoneForStorage is an identity when granular permissions are disabled", function (assert) {
    assert.deepEqual(
      mapLoggedInUsersToEveryoneForStorage(["5", "1"], false, "0|1", "|"),
      ["5", "1"]
    );
  });

  test("mapLoggedInUsersToEveryoneForStorage keeps logged_in_users when the stored value never contained everyone", function (assert) {
    assert.deepEqual(
      mapLoggedInUsersToEveryoneForStorage(["5", "1"], true, "1", "|"),
      ["5", "1"]
    );
  });

  test("mapLoggedInUsersToEveryoneForStorage keeps logged_in_users when the stored value already distinguishes both groups", function (assert) {
    assert.deepEqual(
      mapLoggedInUsersToEveryoneForStorage(["5", "1"], true, "0|5", "|"),
      ["5", "1"]
    );
  });

  test("mapLoggedInUsersToEveryoneForStorage maps logged_in_users back to everyone when the stored value contained everyone", function (assert) {
    assert.deepEqual(
      mapLoggedInUsersToEveryoneForStorage(["5", "1"], true, "0|1", "|"),
      ["0", "1"]
    );
  });

  test("mapLoggedInUsersToEveryoneForStorage handles a blank stored value", function (assert) {
    assert.deepEqual(
      mapLoggedInUsersToEveryoneForStorage(["5"], true, undefined, "|"),
      ["5"]
    );
  });

  test("mapLoggedInUsersToEveryoneForStorage dedupes when the selection contains both groups", function (assert) {
    assert.deepEqual(
      mapLoggedInUsersToEveryoneForStorage(["0", "5"], true, "0", "|"),
      ["0"]
    );
  });
});
