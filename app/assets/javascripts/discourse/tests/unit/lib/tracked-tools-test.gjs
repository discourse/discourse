import { cached } from "@glimmer/tracking";
import { run } from "@ember/runloop";
import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { dedupeTracked, DeferredTrackedSet } from "discourse/lib/tracked-tools";

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
});
