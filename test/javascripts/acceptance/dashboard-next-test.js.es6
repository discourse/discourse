import { acceptance } from "helpers/qunit-helpers";

acceptance("Dashboard Next", {
  loggedIn: true
});

QUnit.test("Visit dashboard next page", assert => {
  visit("/admin");

  andThen(() => {
    assert.ok($(".dashboard-next").length, "has dashboard-next class");

    assert.ok($(".dashboard-mini-chart.signups").length, "has a signups chart");

    assert.ok($(".dashboard-mini-chart.posts").length, "has a posts chart");

    assert.ok(
      $(".dashboard-mini-chart.dau_by_mau").length,
      "has a dau_by_mau chart"
    );

    assert.ok(
      $(".dashboard-mini-chart.daily_engaged_users").length,
      "has a daily_engaged_users chart"
    );

    assert.ok(
      $(".dashboard-mini-chart.new_contributors").length,
      "has a new_contributors chart"
    );

    assert.equal(
      $(".section.dashboard-problems .problem-messages ul li:first-child")
        .html()
        .trim(),
      "Houston...",
      "displays problems"
    );
  });
});
