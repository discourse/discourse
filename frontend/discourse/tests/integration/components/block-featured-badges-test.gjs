import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import FeaturedBadges from "discourse/blocks/builtin/featured-badges";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function grantsResponse() {
  return {
    user_badge_info: {
      user_badges: [
        {
          id: 11,
          granted_at: "2024-01-02T00:00:00.000Z",
          badge_id: 1,
          user_id: 1,
        },
        {
          id: 12,
          granted_at: "2024-01-01T00:00:00.000Z",
          badge_id: 2,
          user_id: 2,
        },
      ],
    },
    badges: [
      { id: 1, name: "Anniversary", icon: "fa-cake", badge_type_id: 1 },
      { id: 2, name: "Editor", icon: "fa-pencil", badge_type_id: 1 },
    ],
    badge_types: [{ id: 1, name: "Gold" }],
    users: [
      { id: 1, username: "alice", avatar_template: "/images/avatar.png" },
      { id: 2, username: "bob", avatar_template: "/images/avatar.png" },
    ],
  };
}

module("Integration | Blocks | featured-badges", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    resetBlockData();
  });

  test("renders a row per recent recipient", async function (assert) {
    pretender.get("/user_badges/featured.json", () =>
      response(grantsResponse())
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: FeaturedBadges, args: { badges: "1|2" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-featured-badges__list");
    await settled();

    assert
      .dom(".d-block-featured-badges__item")
      .exists({ count: 2 }, "renders one row per resolved grant");
    assert
      .dom(".d-block-featured-badges__list")
      .includesText("alice", "renders the first recipient")
      .includesText("bob", "renders the second recipient");
    assert
      .dom(".d-block-featured-badges__badge")
      .exists({ count: 2 }, "renders the earned badge per row");
  });

  test("renders the empty state when there are no recent grants", async function (assert) {
    pretender.get("/user_badges/featured.json", () =>
      response({ user_badge_info: { user_badges: [] }, badges: [], users: [] })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: FeaturedBadges, args: { badges: "1|2" } },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);
    await waitFor(".d-block-featured-badges__empty");
    await settled();

    assert
      .dom(".d-block-featured-badges__empty")
      .exists("the empty branch renders when nothing is granted");
    assert
      .dom(".d-block-featured-badges__list")
      .doesNotExist("no list when there are no grants");
  });
});
