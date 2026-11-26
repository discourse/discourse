import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DTapTile from "discourse/ui-kit/d-tap-tile";
import DTapTileGrid from "discourse/ui-kit/d-tap-tile-grid";

const noop = () => {};

module("Integration | ui-kit | DTapTile", function (hooks) {
  setupRenderingTest(hooks);

  test("marks the tile matching @activeTile as active", async function (assert) {
    await render(
      <template>
        <DTapTile @activeTile="60" @onChange={{noop}} @tileId="30" />
        <DTapTile @activeTile="60" @onChange={{noop}} @tileId="60" />
      </template>
    );

    assert
      .dom("#tap_tile_60")
      .hasClass("active", "the matching tile is active")
      .hasAria("pressed", "true", "the matching tile is pressed");
    assert
      .dom("#tap_tile_30")
      .doesNotHaveClass("active", "another tile is not active")
      .hasAria("pressed", "false", "another tile is not pressed");
  });

  test("reports its id on click and on Enter", async function (assert) {
    const chosen = [];
    const onChange = (id) => chosen.push(id);

    await render(
      <template>
        <DTapTile @onChange={{onChange}} @tileId="tomorrow" />
      </template>
    );
    await click("#tap_tile_tomorrow");
    await triggerKeyEvent("#tap_tile_tomorrow", "keydown", "Enter");
    await triggerKeyEvent("#tap_tile_tomorrow", "keydown", "Space");

    assert.deepEqual(
      chosen,
      ["tomorrow", "tomorrow"],
      "click and Enter report the id, other keys do not"
    );
  });

  test("renders @icon, the block and attributes", async function (assert) {
    await render(
      <template>
        <DTapTile class="extra" @icon="clock" @onChange={{noop}} @tileId="30">
          30 minutes
        </DTapTile>
      </template>
    );

    assert
      .dom("#tap_tile_30")
      .hasClass("extra", "attributes are applied")
      .hasClass("tap-tile", "the tile keeps its own class")
      .hasText("30 minutes", "the block is rendered");
    assert.dom("#tap_tile_30 .d-icon-clock").exists("the icon is rendered");
  });
});

module("Integration | ui-kit | DTapTileGrid", function (hooks) {
  setupRenderingTest(hooks);

  test("yields @activeTile to its tiles", async function (assert) {
    await render(
      <template>
        <DTapTileGrid class="extra" @activeTile="60" as |grid|>
          <DTapTile
            @activeTile={{grid.activeTile}}
            @onChange={{noop}}
            @tileId="60"
          />
        </DTapTileGrid>
      </template>
    );

    assert.dom(".tap-tile-grid").hasClass("extra", "attributes reach the grid");
    assert
      .dom(".tap-tile-grid #tap_tile_60")
      .hasClass("active", "the yielded active tile reaches the tile");
  });
});
