import { module, test } from "qunit";
import { except } from "discourse/lib/collections";

module("Unit | Utility | collections | except", function () {
  test("it returns all items of the left array that aren't in the right array", function (assert) {
    const left = [1, 2, 3, 4, 5];
    const right = [1, 2];

    const result = except(left, right);

    assert.deepEqual(result, [3, 4, 5]);
  });

  test("it returns an empty array if arrays are identical", function (assert) {
    const left = [1, 2, 3, 4];
    const right = [1, 2, 3, 4];

    const result = except(left, right);

    assert.equal(result.length, 0);
  });

  test("it doesn't care if items in arrays are in different order", function (assert) {
    const left = [1, 2, 3, 4, 5];
    const right = [4, 3, 2, 1];

    const result = except(left, right);

    assert.deepEqual(result, [5]);
  });

  test("it correctly handles repeated items in the left array", function (assert) {
    const left = [1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3];
    const right = [1, 2];

    const result = except(left, right);

    assert.deepEqual(result, [3, 3, 3, 3]);
  });

  test("it doesn't care if the right array has repeated items", function (assert) {
    const left = [1, 2, 3, 4, 5];
    const right = [1, 1, 1, 1, 1, 2, 2, 2, 2];

    const result = except(left, right);

    assert.deepEqual(result, [3, 4, 5]);
  });
});
