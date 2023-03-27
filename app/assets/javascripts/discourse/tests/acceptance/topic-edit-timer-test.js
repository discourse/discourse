import {
  acceptance,
  exists,
  fakeTime,
  loggedInUser,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "I18n";
import { cloneJSON } from "discourse-common/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";

acceptance("Topic - Edit timer", function (needs) {
  let clock = null;
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/t/280/timer", () =>
      helper.response({
        success: "OK",
        execute_at: new Date(
          new Date().getTime() + 1 * 60 * 60 * 1000
        ).toISOString(),
        duration_minutes: 1440,
        based_on_last_post: false,
        closed: false,
        category_id: null,
      })
    );

    const topicResponse = cloneJSON(topicFixtures["/t/54077.json"]);
    topicResponse.details.can_delete = false;
    server.get("/t/54077.json", () => helper.response(topicResponse));
  });

  needs.hooks.beforeEach(() => {
    const timezone = loggedInUser().user_option.timezone;
    const tuesday = "2100-06-15T08:00:00";
    clock = fakeTime(tuesday, timezone, true);
  });

  needs.hooks.afterEach(() => {
    clock.restore();
  });

  test("autoclose - specific time", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await click("#tap_tile_start_of_next_business_week");

    const regex = /will automatically close in/g;
    const html = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerHTML.trim();
    assert.ok(regex.test(html));
  });

  test("autoclose", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await click("#tap_tile_start_of_next_business_week");

    const regex1 = /will automatically close in/g;
    const html1 = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerHTML.trim();
    assert.ok(regex1.test(html1));

    await click("#tap_tile_custom");
    await fillIn(".tap-tile-date-input .date-picker", "2100-11-24");

    const regex2 = /will automatically close in/g;
    const html2 = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerHTML.trim();
    assert.ok(regex2.test(html2));

    const timerType = selectKit(".select-kit.timer-type");
    await timerType.expand();
    await timerType.selectRowByValue("close_after_last_post");

    const interval = selectKit(".select-kit.relative-time-intervals");
    await interval.expand();
    await interval.selectRowByValue("hours");
    await fillIn(".relative-time-duration", "2");

    const regex3 = /last post in the topic is already/g;
    const html3 = query(".edit-topic-timer-modal .warning").innerHTML.trim();
    assert.ok(regex3.test(html3));
  });

  test("close temporarily", async function (assert) {
    updateCurrentUser({ moderator: true });
    const timerType = selectKit(".select-kit.timer-type");

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await timerType.expand();
    await timerType.selectRowByValue("open");

    await click("#tap_tile_start_of_next_business_week");

    const regex1 = /will automatically open in/g;
    const html1 = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerHTML.trim();
    assert.ok(regex1.test(html1));

    await click("#tap_tile_custom");
    await fillIn(".tap-tile-date-input .date-picker", "2100-11-24");

    const regex2 = /will automatically open in/g;
    const html2 = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerHTML.trim();
    assert.ok(regex2.test(html2));
  });

  test("schedule publish to category - visible for a PM", async function (assert) {
    updateCurrentUser({ moderator: true });
    const timerType = selectKit(".select-kit.timer-type");
    const categoryChooser = selectKit(".modal-body .category-chooser");

    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await timerType.expand();
    await timerType.selectRowByValue("publish_to_category");

    assert.strictEqual(categoryChooser.header().label(), "category…");
    assert.strictEqual(categoryChooser.header().value(), null);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue("7");

    await click("#tap_tile_start_of_next_business_week");

    const text = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerText.trim();

    // this needs to be done because there is no simple way to get the
    // plain text version of a translation with HTML
    let el = document.createElement("p");
    el.innerHTML = I18n.t(
      "topic.status_update_notice.auto_publish_to_category",
      {
        categoryUrl: "/c/dev/7",
        categoryName: "dev",
        timeLeft: "in 6 days",
      }
    );

    assert.strictEqual(text, el.innerText);
  });

  test("schedule publish to category - visible for a private category", async function (assert) {
    updateCurrentUser({ moderator: true });
    const timerType = selectKit(".select-kit.timer-type");
    const categoryChooser = selectKit(".modal-body .category-chooser");

    // has private category id 24 (shared drafts)
    await visit("/t/some-topic/9");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await timerType.expand();
    await timerType.selectRowByValue("publish_to_category");

    assert.strictEqual(categoryChooser.header().label(), "category…");
    assert.strictEqual(categoryChooser.header().value(), null);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue("7");

    await click("#tap_tile_start_of_next_business_week");

    const text = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerText.trim();

    // this needs to be done because there is no simple way to get the
    // plain text version of a translation with HTML
    let el = document.createElement("p");
    el.innerHTML = I18n.t(
      "topic.status_update_notice.auto_publish_to_category",
      {
        categoryUrl: "/c/dev/7",
        categoryName: "dev",
        timeLeft: "in 6 days",
      }
    );

    assert.strictEqual(text, el.innerText);
  });

  test("schedule publish to category - visible for an unlisted public topic", async function (assert) {
    updateCurrentUser({ moderator: true });
    const timerType = selectKit(".select-kit.timer-type");
    const categoryChooser = selectKit(".modal-body .category-chooser");

    await visit("/t/internationalization-localization/280");

    // make topic not visible
    await click(".toggle-admin-menu");
    await click(".topic-admin-visible .btn");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await timerType.expand();
    await timerType.selectRowByValue("publish_to_category");

    assert.strictEqual(categoryChooser.header().label(), "category…");
    assert.strictEqual(categoryChooser.header().value(), null);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue("7");

    await click("#tap_tile_start_of_next_business_week");

    const text = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerText.trim();

    // this needs to be done because there is no simple way to get the
    // plain text version of a translation with HTML
    let el = document.createElement("p");
    el.innerHTML = I18n.t(
      "topic.status_update_notice.auto_publish_to_category",
      {
        categoryUrl: "/c/dev/7",
        categoryName: "dev",
        timeLeft: "in 6 days",
      }
    );

    assert.strictEqual(text, el.innerText);
  });

  test("schedule publish to category - last custom date and time", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/internationalization-localization");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    assert.notOk(
      exists("#tap_tile_last_custom"),
      "it does not show last custom if the custom date and time was not filled before"
    );

    await click(".modal-close");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_custom");
    await fillIn(".tap-tile-date-input .date-picker", "2100-11-24");
    await fillIn("#custom-time", "10:30");
    await click(".edit-topic-timer-buttons button.btn-primary");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert.ok(
      exists("#tap_tile_last_custom"),
      "it show last custom because the custom date and time was valid"
    );
    const text = query("#tap_tile_last_custom").innerText.trim();
    const regex = /Nov 24, 10:30 am/g;
    assert.ok(regex.test(text));
  });

  test("schedule publish to category - does not show for a public topic", async function (assert) {
    updateCurrentUser({ moderator: true });
    const timerType = selectKit(".select-kit.timer-type");

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await timerType.expand();
    assert.notOk(
      timerType.rowByValue("publish_to_category").exists(),
      "publish to category is not shown for a public topic"
    );
  });

  test("TL4 can't auto-delete", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/short-topic-with-two-posts/54077");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    const timerType = selectKit(".select-kit.timer-type");

    await timerType.expand();

    assert.ok(!timerType.rowByValue("delete").exists());
  });

  test("Category Moderator can auto-delete replies", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    const timerType = selectKit(".select-kit.timer-type");

    await timerType.expand();

    assert.ok(timerType.rowByValue("delete_replies").exists());
  });

  test("TL4 can't auto-delete replies", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/short-topic-with-two-posts/54077");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    const timerType = selectKit(".select-kit.timer-type");

    await timerType.expand();

    assert.ok(!timerType.rowByValue("delete_replies").exists());
  });

  test("Category Moderator can auto-delete", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    const timerType = selectKit(".select-kit.timer-type");

    await timerType.expand();

    assert.ok(timerType.rowByValue("delete").exists());
  });

  test("auto delete", async function (assert) {
    updateCurrentUser({ moderator: true });
    const timerType = selectKit(".select-kit.timer-type");

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await timerType.expand();
    await timerType.selectRowByValue("delete");

    await click("#tap_tile_two_weeks");

    const regex = /will be automatically deleted/g;
    const html = query(
      ".edit-topic-timer-modal .topic-timer-info"
    ).innerHTML.trim();
    assert.ok(regex.test(html));
  });

  test("Inline delete timer", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_start_of_next_business_week");
    await click(".edit-topic-timer-buttons button.btn-primary");

    const removeTimerButton = query(".topic-timer-info .topic-timer-remove");
    assert.strictEqual(removeTimerButton.getAttribute("title"), "remove timer");

    await click(".topic-timer-info .topic-timer-remove");
    assert.ok(!exists(".topic-timer-info .topic-timer-remove"));
  });

  test("Shows correct time frame options", async function (assert) {
    this.siteSettings.suggest_weekends_in_date_pickers = true;
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert.deepEqual(
      [...queryAll("div.tap-tile-grid div.tap-tile-title")].map((el) =>
        el.innerText.trim()
      ),
      [
        I18n.t("time_shortcut.tomorrow"),
        I18n.t("time_shortcut.this_weekend"),
        I18n.t("time_shortcut.start_of_next_business_week"),
        I18n.t("time_shortcut.two_weeks"),
        I18n.t("time_shortcut.next_month"),
        I18n.t("time_shortcut.six_months"),
        I18n.t("time_shortcut.custom"),
      ]
    );
  });

  test("Does not show timer notice unless timer set", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    const timerType = selectKit(".select-kit.timer-type");
    await timerType.expand();
    await timerType.selectRowByValue("close_after_last_post");

    assert.notOk(exists(".topic-timer-heading"));
  });
});
