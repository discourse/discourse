import { click, fillIn, select, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  fakeTime,
  loggedInUser,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Topic - Edit timer", function (needs) {
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

  needs.hooks.beforeEach(function () {
    this.timezone = loggedInUser().user_option.timezone;
    const tuesday = "2100-06-15T08:00:00";
    this.clock = fakeTime(tuesday, this.timezone, true);
  });

  needs.hooks.afterEach(function () {
    this.clock.restore();
  });

  test("autoclose - specific time", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_start_of_next_business_week");

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .matchesText(/will automatically close in/g);
  });

  test("autoclose", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_start_of_next_business_week");

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .matchesText(/will automatically close in/);

    await click("#tap_tile_custom");
    await fillIn(".tap-tile-date-input .date-picker", "2100-11-24");

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .matchesText(/will automatically close in/);

    await select(".timer-type", "close_after_last_post");

    const interval = selectKit(".select-kit.relative-time-intervals");
    await interval.expand();
    await interval.selectRowByValue("hours");

    assert.strictEqual(interval.header().label(), "hours");
    await fillIn(".relative-time-duration", "2");

    assert
      .dom(".edit-topic-timer-modal .warning")
      .matchesText(
        /last post in the topic is already/,
        "shows the warning if the topic will be closed immediately"
      );

    const topic = topicFixtures["/t/54077.json"];
    const lastPostIndex = topic.post_stream.posts.length - 1;
    const time = topic.post_stream.posts[lastPostIndex].updated_at;
    this.clock.restore();
    this.clock = fakeTime(time, this.timezone, true);
    await fillIn(".relative-time-duration", "6");

    assert
      .dom(".topic-timer-heading")
      .hasText("This topic will close 6 hours after the last reply.");

    await interval.expand();
    await interval.selectRowByValue("days");

    assert.strictEqual(interval.header().label(), "days");
    assert
      .dom(".topic-timer-heading")
      .hasText("This topic will close 6 days after the last reply.");
  });

  test("close temporarily", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await select(".timer-type", "open");
    await click("#tap_tile_start_of_next_business_week");

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .matchesText(/will automatically open in/g);

    await click("#tap_tile_custom");
    await fillIn(".tap-tile-date-input .date-picker", "2100-11-24");

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .matchesText(/will automatically open in/g);
  });

  test("schedule publish to category - visible for a PM", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/pm-for-testing/12");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await select(".timer-type", "publish_to_category");
    const categoryChooser = selectKit(".d-modal__body .category-chooser");

    assert.strictEqual(categoryChooser.header().label(), "category…");
    assert.strictEqual(categoryChooser.header().value(), null);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue("7");

    await click("#tap_tile_start_of_next_business_week");

    // this needs to be done because there is no simple way to get the
    // plain text version of a translation with HTML
    let el = document.createElement("p");
    el.innerHTML = i18n("topic.status_update_notice.auto_publish_to_category", {
      categoryUrl: "/c/dev/7",
      categoryName: "dev",
      timeLeft: "in 6 days",
    });

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .hasText(el.innerText);
  });

  test("schedule publish to category - visible for a private category", async function (assert) {
    updateCurrentUser({ moderator: true });

    // has private category id 24 (shared drafts)
    await visit("/t/some-topic/9");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await select(".timer-type", "publish_to_category");
    const categoryChooser = selectKit(".d-modal__body .category-chooser");

    assert.strictEqual(categoryChooser.header().label(), "category…");
    assert.strictEqual(categoryChooser.header().value(), null);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue("7");

    await click("#tap_tile_start_of_next_business_week");

    // this needs to be done because there is no simple way to get the
    // plain text version of a translation with HTML
    let el = document.createElement("p");
    el.innerHTML = i18n("topic.status_update_notice.auto_publish_to_category", {
      categoryUrl: "/c/dev/7",
      categoryName: "dev",
      timeLeft: "in 6 days",
    });

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .hasText(el.innerText);
  });

  test("schedule publish to category - visible for an unlisted public topic", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization/280");

    // make topic not visible
    await click(".toggle-admin-menu");
    await click(".topic-admin-visible .btn");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    await select(".timer-type", "publish_to_category");
    const categoryChooser = selectKit(".d-modal__body .category-chooser");

    assert.strictEqual(categoryChooser.header().label(), "category…");
    assert.strictEqual(categoryChooser.header().value(), null);

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue("7");

    await click("#tap_tile_start_of_next_business_week");

    // this needs to be done because there is no simple way to get the
    // plain text version of a translation with HTML
    let el = document.createElement("p");
    el.innerHTML = i18n("topic.status_update_notice.auto_publish_to_category", {
      categoryUrl: "/c/dev/7",
      categoryName: "dev",
      timeLeft: "in 6 days",
    });

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .hasText(el.innerText);
  });

  test("schedule publish to category - last custom date and time", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/t/internationalization-localization");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    assert
      .dom("#tap_tile_last_custom")
      .doesNotExist(
        "it does not show last custom if the custom date and time was not filled before"
      );

    await click(".modal-close");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_custom");
    await fillIn(".tap-tile-date-input .date-picker", "2100-11-24");
    await fillIn("#custom-time", "10:30");
    await click(".edit-topic-timer-modal button.btn-primary");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert
      .dom("#tap_tile_last_custom")
      .exists("it show last custom because the custom date and time was valid");

    assert.dom("#tap_tile_last_custom").matchesText(/Nov 24, 10:30 am/g);
  });

  test("schedule publish to category - does not show for a public topic", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert
      .dselect(".timer-type")
      .hasNoOption(
        "publish_to_category",
        "publish to category is not shown for a public topic"
      );
  });

  test("TL4 can't auto-delete", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/short-topic-with-two-posts/54077");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert.dselect(".timer-type").hasNoOption("delete");
  });

  test("Category Moderator can auto-delete replies", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert.dselect(".timer-type").hasOption({
      value: "delete_replies",
      label: i18n("topic.auto_delete_replies.title"),
    });
  });

  test("TL4 can't auto-delete replies", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/short-topic-with-two-posts/54077");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert.dselect(".timer-type").hasNoOption("delete_replies");
  });

  test("Category Moderator can auto-delete", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");

    assert
      .dselect(".timer-type")
      .hasOption({ value: "delete", label: i18n("topic.auto_delete.title") });
  });

  test("auto delete", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await select(".timer-type", "delete");
    await click("#tap_tile_two_weeks");

    assert
      .dom(".edit-topic-timer-modal .topic-timer-info")
      .matchesText(/will be automatically deleted/g);
  });

  test("Inline delete timer", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_start_of_next_business_week");
    await click(".edit-topic-timer-modal button.btn-primary");

    assert
      .dom(".topic-timer-info .topic-timer-remove")
      .hasAttribute("title", "remove timer");

    await click(".topic-timer-info .topic-timer-remove");
    assert.dom(".topic-timer-info .topic-timer-remove").doesNotExist();
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
        i18n("time_shortcut.tomorrow"),
        i18n("time_shortcut.this_weekend"),
        i18n("time_shortcut.start_of_next_business_week"),
        i18n("time_shortcut.two_weeks"),
        i18n("time_shortcut.next_month"),
        i18n("time_shortcut.six_months"),
        i18n("time_shortcut.custom"),
      ]
    );
  });

  test("Does not show timer notice unless timer set", async function (assert) {
    updateCurrentUser({ moderator: true });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await select(".timer-type", "close_after_last_post");

    assert.dom(".topic-timer-heading").doesNotExist();
  });

  test("Close timer removed after manual close", async function (assert) {
    updateCurrentUser({ moderator: true, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_tomorrow");
    await click(".edit-topic-timer-modal button.btn-primary");

    await click(".toggle-admin-menu");
    await click(".topic-admin-close button");

    assert.dom(".topic-timer-heading").doesNotExist();
  });

  test("Open timer removed after manual open", async function (assert) {
    updateCurrentUser({ moderator: true, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".topic-admin-close button");

    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_tomorrow");
    await click(".edit-topic-timer-modal button.btn-primary");

    await click(".toggle-admin-menu");
    await click(".topic-admin-open button");

    assert.dom(".topic-timer-heading").doesNotExist();
  });

  test("timer removed after manual toggle close and open", async function (assert) {
    updateCurrentUser({ moderator: true, trust_level: 4 });

    await visit("/t/internationalization-localization");
    await click(".toggle-admin-menu");
    await click(".admin-topic-timer-update button");
    await click("#tap_tile_tomorrow");
    await click(".edit-topic-timer-modal button.btn-primary");

    await click(".toggle-admin-menu");
    await click(".topic-admin-close button");

    await click(".toggle-admin-menu");
    await click(".topic-admin-open button");

    assert.dom(".topic-timer-heading").doesNotExist();
  });
});
