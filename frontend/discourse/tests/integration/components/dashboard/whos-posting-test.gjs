import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import WhosPosting from "discourse/admin/components/dashboard/engagement/whos-posting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | WhosPosting", function (hooks) {
  setupRenderingTest(hooks);

  const start = new Date("2026-04-01");
  const end = new Date("2026-04-30");

  const posters = {
    total: 100,
    rows: [
      { type: "new_members", count: 34, share: 34 },
      { type: "returning", count: 51, share: 51 },
      { type: "staff", count: 15, share: 15 },
    ],
  };

  test("renders the stacked bar segments and legend rows", async function (assert) {
    await render(
      <template>
        <WhosPosting
          @posters={{posters}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-whos-posting__bar").exists();
    assert.dom(".db-whos-posting__segment").exists({ count: 3 });
    assert.dom(".db-whos-posting__legend-item").exists({ count: 3 });
    assert
      .dom(
        ".db-whos-posting__legend-item:nth-child(1) .db-whos-posting__legend-label"
      )
      .hasText("New members");
    assert
      .dom(
        ".db-whos-posting__legend-item:nth-child(2) .db-whos-posting__legend-share"
      )
      .hasText("51%");
  });

  test("renders the section header linking to the posters_by_member_type report", async function (assert) {
    await render(
      <template>
        <WhosPosting
          @posters={{posters}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert
      .dom("a.db-section__row-block-title.--label")
      .hasText("Who's posting?")
      .hasAttribute("href", /\/admin\/reports\/posters_by_member_type/);
    assert.dom(".category-chooser").exists();
  });

  test("falls back to an empty-state message when there are no posts", async function (assert) {
    const empty = { total: 0, rows: [] };

    await render(
      <template>
        <WhosPosting @posters={{empty}} @startDate={{start}} @endDate={{end}} />
      </template>
    );

    assert.dom(".db-whos-posting__bar").doesNotExist();
    assert.dom(".db-whos-posting__legend").doesNotExist();
    assert.dom(".db-whos-posting__empty").exists();
  });

  test("omits the bar segment for a bucket with zero share", async function (assert) {
    const noStaff = {
      total: 85,
      rows: [
        { type: "new_members", count: 34, share: 40 },
        { type: "returning", count: 51, share: 60 },
        { type: "staff", count: 0, share: 0 },
      ],
    };

    await render(
      <template>
        <WhosPosting
          @posters={{noStaff}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-whos-posting__segment").exists({ count: 2 });
    assert.dom(".db-whos-posting__legend-item").exists({ count: 3 });
  });
});
