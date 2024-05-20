import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { dedupeTracked } from "discourse/lib/tracked-tools";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Unit | tracked-tools", function (hooks) {
  setupRenderingTest(hooks);

  test("@dedupeTracked", async function (assert) {
    class Pet {
      initialsEvaluatedCount = 0;

      @dedupeTracked name;

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

    await render(<template>
      <span id="initials">{{pet.initials}}</span>
    </template>);

    assert.dom("#initials").hasText("SD", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      1,
      "Initials getter evaluated once"
    );

    pet.name = "Scooby Doo";
    await settled();
    assert.dom("#initials").hasText("SD", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      1,
      "Initials getter not re-evaluated"
    );

    pet.name = "Fluffy";
    await settled();
    assert.dom("#initials").hasText("F", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      2,
      "Initials getter re-evaluated"
    );
  });
});
