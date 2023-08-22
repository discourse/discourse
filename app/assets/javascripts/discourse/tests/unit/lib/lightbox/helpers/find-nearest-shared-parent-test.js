import { module, test } from "qunit";

import { findNearestSharedParent } from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | findNearestSharedParent()",
  function () {
    test("it returns the nearest shared parent for the elements passed in", async function (assert) {
      const element0 = document.createElement("div");
      const element1 = document.createElement("div");
      const element2 = document.createElement("div");
      const element3 = document.createElement("div");
      const element4 = document.createElement("div");

      element1.appendChild(element2);
      element3.appendChild(element4);

      element0.appendChild(element1);
      element0.appendChild(element3);

      assert.strictEqual(
        findNearestSharedParent([element2, element4]),
        element0,
        "returns the correct nearest shared parent"
      );
    });
  }
);
