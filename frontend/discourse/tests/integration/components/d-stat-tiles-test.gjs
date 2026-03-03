import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DStatTiles from "discourse/components/d-stat-tiles";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const content = "This is a tooltip";
const label = "Stat Label";

module("Integration | Component | DStatTiles", function (hooks) {
  setupRenderingTest(hooks);

  test("formats the @value in a readable way with the raw number as the title attr", async function (assert) {
    await render(
      <template>
        <DStatTiles as |tiles|>
          <tiles.Tile @value="12555999" @label={{label}} />
        </DStatTiles>
      </template>
    );

    assert
      .dom(".d-stat-tiles .d-stat-tile .d-stat-tile__value")
      .hasText("12.6M");
    assert
      .dom(".d-stat-tiles .d-stat-tile .d-stat-tile__value")
      .hasAttribute("title", "12555999");
  });

  test("renders the @label", async function (assert) {
    await render(
      <template>
        <DStatTiles as |tiles|>
          <tiles.Tile @value="12555999" @label={{label}} />
        </DStatTiles>
      </template>
    );

    assert.dom(".d-stat-tiles .d-stat-tile .d-stat-tile__label").hasText(label);
  });

  test("renders the optional @tooltip", async function (assert) {
    await render(
      <template>
        <DStatTiles as |tiles|>
          <tiles.Tile @value="12555999" @label={{label}} @tooltip={{content}} />
        </DStatTiles>
      </template>
    );

    assert.dom(".d-stat-tile__tooltip").exists();
    await triggerEvent(".fk-d-tooltip__trigger", "pointermove");
    assert.dom(".fk-d-tooltip__content").hasText(content);
  });

  test("wraps the value in a link if @url is provided", async function (assert) {
    await render(
      <template>
        <DStatTiles as |tiles|>
          <tiles.Tile
            @value="12555999"
            @label={{label}}
            @url="https://meta.discourse.org"
          />
        </DStatTiles>
      </template>
    );

    assert
      .dom(".d-stat-tiles .d-stat-tile a.d-stat-tile__value")
      .hasAttribute("href", "https://meta.discourse.org");
  });
});
