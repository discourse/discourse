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

  test("renders a bar row with label, fill and share for each bucket", async function (assert) {
    await render(
      <template>
        <WhosPosting
          @posters={{posters}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-whos-posting__bars").exists();
    assert.dom(".db-whos-posting__bar-row").exists({ count: 3 });
    assert.dom(".db-whos-posting__bar-fill").exists({ count: 3 });
    assert
      .dom(".db-whos-posting__bar-row:nth-child(1) .db-whos-posting__bar-label")
      .hasText("New members");
    assert
      .dom(".db-whos-posting__bar-row:nth-child(2) .db-whos-posting__bar-share")
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

    assert.dom(".db-whos-posting__bars").doesNotExist();
    assert.dom(".db-whos-posting__empty").exists();
  });

  test("renders a zero-share bucket with a 0% share", async function (assert) {
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

    assert.dom(".db-whos-posting__bar-row").exists({ count: 3 });
    assert
      .dom(".db-whos-posting__bar-row:nth-child(3) .db-whos-posting__bar-share")
      .hasText("0%");
  });
});
