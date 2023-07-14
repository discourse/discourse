import { module, test } from "qunit";

import { scrollParentToElementCenter } from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | scrollParentToElementCenter()",
  function () {
    test("scrolls the parent element to the center of the element", async function (assert) {
      const parent = document.createElement("div");
      parent.style.width = "200px";
      parent.style.height = "200px";
      parent.style.overflow = "scroll";

      const element = document.createElement("div");
      element.style.width = "400px";
      element.style.height = "400px";
      parent.appendChild(element);

      document.body.appendChild(parent);

      const getExpectedX = (element.offsetWidth - parent.offsetWidth) / 2;
      const expectedY = (element.offsetHeight - parent.offsetHeight) / 2;

      scrollParentToElementCenter({ element, isRTL: false });

      assert.strictEqual(
        parent.scrollLeft,
        getExpectedX,
        "scrolls parent to center of element (LTR - horizontal)"
      );

      assert.strictEqual(
        parent.scrollTop,
        expectedY,
        "scrolls parent to center of viewport (LTR and RTL - vertical)"
      );

      parent.style.direction = "rtl";

      scrollParentToElementCenter({ element, isRTL: true });

      assert.strictEqual(
        parent.scrollLeft,
        getExpectedX * -1,
        "scrolls parent to center of viewport (RTL - horizontal)"
      );

      document.body.removeChild(parent);
    });
  }
);
