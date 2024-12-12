import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DStatTiles from "discourse/components/d-stat-tiles";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | DStatTiles", function (hooks) {
  setupRenderingTest(hooks);

  test("formats the @value in a readable way with the raw number as the title attr", async function (assert) {
    await render(<template>
      <DStatTiles as |tiles|><tiles.Tile
          @value="12555999"
          @label={{i18n "bootstrap_mode"}}
        /></DStatTiles>
    </template>);

    assert
      .dom(".d-stat-tiles .d-stat-tile .d-stat-tile__value")
      .hasText("12.6M");
    assert
      .dom(".d-stat-tiles .d-stat-tile .d-stat-tile__value")
      .hasAttribute("title", "12555999");
  });

  test("renders the @label", async function (assert) {
    await render(<template>
      <DStatTiles as |tiles|><tiles.Tile
          @value="12555999"
          @label={{i18n "bootstrap_mode"}}
        /></DStatTiles>
    </template>);

    assert
      .dom(".d-stat-tiles .d-stat-tile .d-stat-tile__label")
      .hasText(i18n("bootstrap_mode"));
  });

  test("renders the optional @tooltip", async function (assert) {
    await render(<template>
      <DStatTiles as |tiles|><tiles.Tile
          @value="12555999"
          @label={{i18n "bootstrap_mode"}}
          @tooltip={{i18n "bootstrap_mode"}}
        /></DStatTiles>
    </template>);

    assert.dom(".d-stat-tile__tooltip").exists();
    await triggerEvent(".fk-d-tooltip__trigger", "mousemove");
    assert.dom(".fk-d-tooltip__content").hasText(i18n("bootstrap_mode"));
  });

  test("wraps the value in a link if @url is provided", async function (assert) {
    await render(<template>
      <DStatTiles as |tiles|><tiles.Tile
          @value="12555999"
          @label={{i18n "bootstrap_mode"}}
          @url="https://meta.discourse.org"
        /></DStatTiles>
    </template>);

    assert
      .dom(".d-stat-tiles .d-stat-tile a.d-stat-tile__value")
      .hasAttribute("href", "https://meta.discourse.org");
  });
});
