import { cached } from "@glimmer/tracking";
import { run } from "@ember/runloop";
import { settled } from "@ember/test-helpers";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import {
  dedupeTracked,
  DeferredTrackedSet,
  trackedArray,
} from "discourse/lib/tracked-tools";

module("Unit | tracked-tools", function () {
  test("@dedupeTracked", async function (assert) {
    class Pet {
      initialsEvaluatedCount = 0;

      @dedupeTracked name;

      @cached
      get initials() {
        this.initialsEvaluatedCount++;
        return this.name
          ?.split(" ")
          .map((n) => n[0])
          .join("");
      }
    }

    const pet = new Pet();
    pet.name = "Scooby Doo";

    assert.strictEqual(pet.initials, "SD", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      1,
      "Initials getter evaluated once"
    );

    pet.name = "Scooby Doo";
    assert.strictEqual(pet.initials, "SD", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      1,
      "Initials getter not re-evaluated"
    );

    pet.name = "Fluffy";
    assert.strictEqual(pet.initials, "F", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      2,
      "Initials getter re-evaluated"
    );
  });

  test("DeferredTrackedSet", async function (assert) {
    class Player {
      evaluationsCount = 0;

      letters = new DeferredTrackedSet();

      @cached
      get score() {
        this.evaluationsCount++;
        return this.letters.size;
      }
    }

    const player = new Player();
    assert.strictEqual(player.score, 0, "score is correct");
    assert.strictEqual(player.evaluationsCount, 1, "getter evaluated once");

    run(() => {
      player.letters.add("a");

      assert.strictEqual(player.score, 0, "score does not change");
      assert.strictEqual(
        player.evaluationsCount,
        1,
        "getter does not evaluate"
      );

      player.letters.add("b");
      player.letters.add("c");

      assert.strictEqual(player.score, 0, "score still does not change");
      assert.strictEqual(
        player.evaluationsCount,
        1,
        "getter still does not evaluate"
      );
    });
    await settled();

    assert.strictEqual(player.score, 3, "score is correct");
    assert.strictEqual(player.evaluationsCount, 2, "getter evaluated again");

    run(() => {
      player.letters.add("d");
    });
    await settled();

    assert.strictEqual(player.score, 4, "score is correct");
    assert.strictEqual(player.evaluationsCount, 3, "getter evaluated again");

    run(() => {
      player.letters.add("e");

      assert.strictEqual(player.score, 4, "score is correct");
      assert.strictEqual(
        player.evaluationsCount,
        3,
        "getter does not evaluate"
      );

      player.letters.add("f");
    });
    await settled();

    assert.strictEqual(player.score, 6, "score is correct");
    assert.strictEqual(player.evaluationsCount, 4, "getter evaluated");
    assert.deepEqual([...player.letters], ["a", "b", "c", "d", "e", "f"]);
  });

  module("@trackedArray", function () {
    test("initializes with an array", function (assert) {
      class TestClass {
        @trackedArray items = ["a", "b", "c"];
      }

      const instance = new TestClass();
      assert.true(
        instance.items instanceof TrackedArray,
        "should wrap initial array in TrackedArray"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["a", "b", "c"],
        "should preserve array contents"
      );
    });

    test("accepts null as initial value", function (assert) {
      class TestClass {
        @trackedArray items = null;
      }

      const instance = new TestClass();
      assert.strictEqual(
        instance.items,
        null,
        "should allow null as initial value"
      );
    });

    test("handles setting regular arrays", function (assert) {
      class TestClass {
        @trackedArray items;
      }

      const instance = new TestClass();
      instance.items = ["x", "y", "z"];

      assert.true(
        instance.items instanceof TrackedArray,
        "should wrap new array in TrackedArray"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["x", "y", "z"],
        "should contain new array values"
      );
    });

    test("accepts TrackedArray instances directly", function (assert) {
      class TestClass {
        @trackedArray items = [];
      }

      const instance = new TestClass();
      const trackedArr = new TrackedArray(["foo", "bar"]);
      instance.items = trackedArr;

      assert.strictEqual(
        instance.items,
        trackedArr,
        "should use the provided TrackedArray instance"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["foo", "bar"],
        "should contain correct values"
      );
    });

    test("allows setting to null", function (assert) {
      class TestClass {
        @trackedArray items = ["initial"];
      }

      const instance = new TestClass();
      instance.items = null;

      assert.strictEqual(instance.items, null, "should allow setting to null");
    });

    test("throws error for invalid values", function (assert) {
      class TestClass {
        @trackedArray items = [];
      }

      const instance = new TestClass();

      assert.throws(
        () => {
          instance.items = "not an array";
        },
        /Expected an array or TrackedArray, got string/,
        "should throw for strings"
      );

      assert.throws(
        () => {
          instance.items = 42;
        },
        /Expected an array or TrackedArray, got number/,
        "should throw for numbers"
      );

      assert.throws(
        () => {
          instance.items = {};
        },
        /Expected an array or TrackedArray, got object/,
        "should throw for plain objects"
      );

      assert.throws(
        () => {
          instance.items = undefined;
        },
        /Expected an array or TrackedArray, got undefined/,
        "should throw for undefined"
      );
    });

    test("tracks changes to array contents", function (assert) {
      class TestClass {
        evaluationsCount = 0;
        @trackedArray items = ["a"];

        @cached
        get itemCount() {
          this.evaluationsCount++;
          return this.items.length;
        }

        addItem(item) {
          this.items = [...this.items, item];
        }
      }

      const instance = new TestClass();
      assert.strictEqual(instance.itemCount, 1, "initial count is correct");
      assert.strictEqual(instance.evaluationsCount, 1, "getter evaluated once");

      assert.strictEqual(
        instance.itemCount,
        1,
        "count not updated when reading the value again."
      );
      assert.strictEqual(
        instance.evaluationsCount,
        1,
        "getter wasn't evaluated again"
      );

      instance.addItem("b"); // Adding same item
      assert.strictEqual(
        instance.itemCount,
        2,
        "count updated after duplicate add"
      );
      assert.strictEqual(
        instance.evaluationsCount,
        2,
        "getter re-evaluated after change"
      );

      assert.deepEqual(
        Array.from(instance.items),
        ["a", "b"],
        "array contains correct items"
      );
    });
  });
});
