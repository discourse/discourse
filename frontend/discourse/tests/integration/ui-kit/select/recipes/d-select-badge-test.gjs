import { tracked } from "@glimmer/tracking";
import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import Badge from "discourse/models/badge";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectBadge from "discourse/ui-kit/select/recipes/badges/d-select-badge";

/** One badge of each kind the recipe has to draw. */
function badges() {
  return [
    Badge.create({ id: 1, name: "Spark", icon: "bolt" }),
    Badge.create({
      id: 2,
      name: "Gardener",
      image_url: "/images/gardener.png",
    }),
    Badge.create({ id: 3, name: "Old guard", icon: "fa-certificate" }),
    { id: 5, name: "Archivist", image_url: "/images/archivist.png" },
    Badge.create({
      id: 4,
      name: "Lighthouse",
      icon: "bolt",
      image_url: "/images/lighthouse.png",
    }),
  ];
}

/** The listed option for a badge id. */
function row(id) {
  return find(`[role='option'][data-value='${id}']`);
}

module(
  "Integration | ui-kit | select | recipes | DSelectBadge",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      document.body.style.removeProperty("--d-select-badge-glyph-size");
    });

    test("draws each badge's icon or image before its name", async function (assert) {
      const options = badges();

      await render(<template><DSelectBadge @options={{options}} /></template>);
      await new DSelect().open();

      assert.dom(row(1)).includesText("Spark");
      assert
        .dom(".d-select-badge__glyph .d-icon-bolt", row(1))
        .exists("an icon badge draws its icon");

      assert.dom(row(2)).includesText("Gardener");
      assert
        .dom(".d-select-badge__glyph img", row(2))
        .hasAttribute(
          "src",
          "/images/gardener.png",
          "an image badge draws its image"
        );
      assert
        .dom(".d-select-badge__glyph img", row(2))
        .hasAttribute("alt", "", "the image is decorative beside the name");

      assert
        .dom(".d-select-badge__glyph .d-icon-certificate", row(3))
        .exists("a class-style icon name is converted");

      assert
        .dom(".d-select-badge__glyph img", row(4))
        .exists("a badge with an image draws it");
      assert
        .dom(".d-select-badge__glyph img", row(5))
        .hasAttribute(
          "src",
          "/images/archivist.png",
          "a plain badge record from the server draws its image too"
        );
      assert.dom(".d-icon", row(4)).doesNotExist("and not its icon as well");
    });

    test("shows the held badge's icon or image in the trigger", async function (assert) {
      const options = badges();
      const value = tracked(2);

      await render(
        <template>
          <DSelectBadge @options={{options}} @value={{value.value}} />
        </template>
      );

      assert
        .dom(".d-select__trigger .d-select-badge__glyph img")
        .hasAttribute("src", "/images/gardener.png");
      assert.dom(".d-select__trigger").includesText("Gardener");

      value.value = 1;
      await settled();
      assert
        .dom(".d-select__trigger .d-select-badge__glyph .d-icon-bolt")
        .exists("an icon badge shows its icon");
      assert
        .dom(".d-select__trigger .d-select-badge__glyph img")
        .doesNotExist();
    });

    test("sizes icons and images from one variable", async function (assert) {
      const options = badges();
      // Computed sizes: the test fixture is scaled, so rendered boxes are halved.
      const size = (glyph) => {
        const { width, height } = getComputedStyle(glyph);
        return [width, height];
      };

      // The open list floats outside the select, so the variable is set where both inherit it.
      document.body.style.setProperty("--d-select-badge-glyph-size", "30px");
      await render(
        <template><DSelectBadge @options={{options}} @value={{2}} /></template>
      );

      assert.deepEqual(
        size(find(".d-select__trigger .d-select-badge__glyph img")),
        ["30px", "30px"],
        "the held image follows the variable"
      );

      await new DSelect().open();
      assert.deepEqual(
        size(row(1).querySelector(".d-select-badge__glyph .d-icon")),
        ["30px", "30px"],
        "a listed icon follows the variable"
      );
      assert.deepEqual(
        size(row(2).querySelector(".d-select-badge__glyph img")),
        ["30px", "30px"],
        "a listed image follows the variable"
      );
    });

    test("emits the picked badge's id, and null for none", async function (assert) {
      const options = badges();
      const emitted = [];
      const onChange = (id) => emitted.push(id);

      await render(
        <template>
          <DSelectBadge
            @noneOption={{true}}
            @onChange={{onChange}}
            @options={{options}}
            @value={{1}}
          />
        </template>
      );

      await new DSelect().select(2);
      await new DSelect().open();
      await click("[role='option'].--none");

      assert.deepEqual(emitted, [2, null]);
    });

    test("searches badges by name", async function (assert) {
      const options = badges();

      await render(<template><DSelectBadge @options={{options}} /></template>);
      await new DSelect().search("light");

      assert.deepEqual(
        findAll("[role='option']").map((option) => option.dataset.value),
        ["4"]
      );
    });
  }
);
