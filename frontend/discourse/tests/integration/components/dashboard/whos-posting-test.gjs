import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import WhosPosting from "discourse/admin/components/dashboard/engagement/whos-posting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

module("Integration | Component | Dashboard | WhosPosting", function (hooks) {
  setupRenderingTest(hooks);

  const start = new Date("2026-04-01");
  const end = new Date("2026-04-30");

  const posters = {
    total: 100,
    groups: ["new_members", "returning", "staff"],
    rows: [
      {
        type: "new_members",
        kind: "synthetic",
        name: "New members",
        count: 34,
        share: 34,
      },
      {
        type: "returning",
        kind: "synthetic",
        name: "Returning",
        count: 51,
        share: 51,
      },
      { type: "staff", kind: "synthetic", name: "Staff", count: 15, share: 15 },
    ],
  };

  test("renders a bar row with label, fill and share for each row", async function (assert) {
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

  test("renders a dynamic number of rows, including added groups", async function (assert) {
    const withGroup = {
      total: 120,
      groups: ["new_members", "returning", "staff", "group:5"],
      rows: [
        ...posters.rows,
        {
          type: "group:5",
          kind: "group",
          name: "Support",
          count: 20,
          share: 16.67,
        },
      ],
    };

    await render(
      <template>
        <WhosPosting
          @posters={{withGroup}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-whos-posting__bar-row").exists({ count: 4 });
    assert
      .dom(".db-whos-posting__bar-row:nth-child(4) .db-whos-posting__bar-label")
      .hasText("Support");
    assert
      .dom(".db-whos-posting__bar-row:nth-child(4) .db-whos-posting__bar-fill")
      .hasClass("--group-0");
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
    assert.dom(".multiple-categories-selector").exists();
  });

  test("renders an 'Add group' button", async function (assert) {
    await render(
      <template>
        <WhosPosting
          @posters={{posters}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.dom(".db-whos-posting__add-group").exists();
  });

  test("shows an 'All categories' placeholder when nothing is selected", async function (assert) {
    await render(
      <template>
        <WhosPosting
          @posters={{posters}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.strictEqual(
      selectKit(".multiple-categories-selector").header().label(),
      i18n("category.all")
    );
  });

  test("prefills the selector with the persisted category selection", async function (assert) {
    const withSelection = { ...posters, category_ids: [1, 2] };

    await render(
      <template>
        <WhosPosting
          @posters={{withSelection}}
          @startDate={{start}}
          @endDate={{end}}
        />
      </template>
    );

    assert.strictEqual(
      selectKit(".multiple-categories-selector").header().value(),
      "1,2"
    );
  });

  test("falls back to an empty-state message when there are no posts", async function (assert) {
    const empty = { total: 0, rows: [], groups: [] };

    await render(
      <template>
        <WhosPosting @posters={{empty}} @startDate={{start}} @endDate={{end}} />
      </template>
    );

    assert.dom(".db-whos-posting__bars").doesNotExist();
    assert.dom(".db-whos-posting__empty").exists();
  });

  test("renders a zero-share row with a 0% share", async function (assert) {
    const noStaff = {
      total: 85,
      groups: ["new_members", "returning", "staff"],
      rows: [
        {
          type: "new_members",
          kind: "synthetic",
          name: "New members",
          count: 34,
          share: 40,
        },
        {
          type: "returning",
          kind: "synthetic",
          name: "Returning",
          count: 51,
          share: 60,
        },
        { type: "staff", kind: "synthetic", name: "Staff", count: 0, share: 0 },
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
