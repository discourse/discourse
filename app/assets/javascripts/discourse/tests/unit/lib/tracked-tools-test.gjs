import { cached } from "@glimmer/tracking";
import { module, test } from "qunit";
import { dedupeTracked } from "discourse/lib/tracked-tools";

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
});
