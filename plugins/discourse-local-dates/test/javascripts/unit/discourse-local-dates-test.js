import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import freezeTime from "../helpers/freeze-time";
import { applyLocalDates } from "../initializers/discourse-local-dates";

module("Unit | discourse-local-dates", function (hooks) {
  setupTest(hooks);

  function createElementFromHTML(htmlString) {
    const div = document.createElement("div");
    div.innerHTML = htmlString.trim();
    // we need "element", not "node", since `.dataset` isn't available on nodes
    return div.firstElementChild;
  }

  const fromElement = () =>
    createElementFromHTML(
      "<span " +
        'data-date="2022-10-06" ' +
        'data-time="17:21:00" ' +
        'class="discourse-local-date" ' +
        'data-range="from" ' +
        'data-timezone="Asia/Singapore" ' +
        'data-title="Testing dates with the local date builder">' +
        "</span>"
    );
  const toElement = () =>
    createElementFromHTML(
      "<span " +
        'data-date="2022-10-06" ' +
        'data-time="22:22:00" ' +
        'class="discourse-local-date" ' +
        'data-range="to" ' +
        'data-timezone="Asia/Singapore" ' +
        'data-title="Testing dates with the local date builder">' +
        "</span>"
    );

  test("applyLocalDates sets formatted relative time", function (assert) {
    const from = fromElement();
    const to = toElement();
    const dateElements = [from, to];

    freezeTime(
      { date: "2022-10-07T10:10:10", timezone: "Asia/Singapore" },
      () => {
        applyLocalDates(dateElements, {
          discourse_local_dates_enabled: true,
        });

        assert.dom(".relative-time", from).hasText("Yesterday 5:21 PM");
        assert.dom(".relative-time", to).hasText("10:22 PM (Singapore)");
      }
    );
  });

  test("applyLocalDates does not fail when a date element has no time", function (assert) {
    const from = fromElement();
    const to = toElement();
    delete to.dataset.time;
    const dateElements = [from, to];

    freezeTime(
      { date: "2022-10-07T10:10:10", timezone: "Asia/Singapore" },
      () => {
        applyLocalDates(dateElements, {
          discourse_local_dates_enabled: true,
        });

        assert.dom(".relative-time", from).hasText("Yesterday 5:21 PM");
        assert.dom(".relative-time", to).hasText("Yesterday");
      }
    );
  });
});
