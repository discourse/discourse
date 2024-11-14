import { module, test } from "qunit";
import { setCarouselScrollPosition } from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | setCarouselScrollPosition()",
  function () {
    const carouselItemSize = 100;
    const target = 9;

    const carousel = document.createElement("div");
    carousel.style.cssText = `
        display: grid;
        height: 400px;
        width: 400px;
        overflow: auto;
        position: relative;
      `;

    const carouselItem = document.createElement("div");
    carouselItem.style.cssText = `
      width: ${carouselItemSize}px;
      height: ${carouselItemSize}px;
      `;

    Array(20)
      .fill(null)
      .map((_, index) => {
        const item = carouselItem.cloneNode(true);
        if (index === target) {
          item.dataset.lightboxCarouselItem = "current";
        }
        carousel.appendChild(item);
      });

    const expected =
      target * carouselItemSize - carouselItemSize - carouselItemSize / 2;

    test("scrolls the carousel to the center of the active item ", async function (assert) {
      const container = carousel.cloneNode(true);

      container.style.cssText += `
        grid-auto-flow: column;
        grid-template-columns: repeat(auto, ${carouselItemSize}px);
      `;

      const fixtureDiv = document.getElementById("qunit-fixture");
      fixtureDiv.appendChild(container);

      await setCarouselScrollPosition("instant");

      assert.strictEqual(
        container.scrollLeft,
        expected,
        "scrolls carousel to center of active item (horizontal)"
      );

      container.style.cssText += `
        grid-auto-flow: row;
        grid-template-rows: repeat(auto, ${carouselItemSize}px);
      `;

      await setCarouselScrollPosition("instant");

      assert.strictEqual(
        container.scrollTop,
        expected,
        "scrolls carousel to center of active item (vertical)"
      );
    });
  }
);
