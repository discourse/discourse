import { tracked } from "@glimmer/tracking";
import { focus, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import DSelectTimezone from "discourse/ui-kit/select/recipes/timezones/d-select-timezone";

/** The text of every group heading in the open list, in order. */
function headings() {
  return [...document.querySelectorAll(".d-select__group-header")].map(
    (header) => header.textContent.trim()
  );
}

/** Scrolls the open list to its end, so the windowed list draws its last rows. */
async function scrollToEnd() {
  const list = [
    ...document.querySelectorAll(".d-select__panel, .d-select__panel *"),
  ].find((element) => element.scrollHeight > element.clientHeight + 1);
  list.scrollTop = list.scrollHeight;
  await triggerEvent(list, "scroll");
}

/** The open list's row for a zone. */
function row(zone) {
  return document.querySelector(
    `.d-select__panel [role='option'][data-value='${zone}']`
  );
}

module(
  "Integration | ui-kit | select | recipes | DSelectTimezone",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.clock = fakeTime("2026-11-24T18:00:00Z", "UTC", true);
      sinon.stub(moment.tz, "guess").returns("Europe/Lisbon");
    });

    hooks.afterEach(function () {
      this.clock.restore();
    });

    test("time zones: names a zone by its city and country, with its time and offset", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("sao paulo");

      assert.dSelect().hasOptions(["America/Sao_Paulo"]);
      assert.dom(row("America/Sao_Paulo")).includesText("Sao Paulo, Brazil");
      assert
        .dom(".d-select-timezone__time", row("America/Sao_Paulo"))
        .hasText("3:00 PM", "the zone's current time");
      assert
        .dom(".d-select-timezone__offset", row("America/Sao_Paulo"))
        .hasText("GMT-3");
      assert
        .dom(".d-select__option-description", row("America/Sao_Paulo"))
        .hasText("Brasilia Standard Time", "the zone's common name");
    });

    test("time zones: marks a zone that is already tomorrow or still yesterday", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();

      await select.search("auckland");
      assert
        .dom(".d-select-timezone__day", row("Pacific/Auckland"))
        .hasText("Tomorrow", "7:00 AM the next day, seen from Lisbon");

      await select.search("honolulu");
      assert
        .dom(".d-select-timezone__day", row("Pacific/Honolulu"))
        .doesNotExist("8:00 AM the same day");
      await select.close();

      this.clock.tick(8 * 60 * 60 * 1000);
      await select.open();
      await select.search("honolulu");

      assert
        .dom(".d-select-timezone__day", row("Pacific/Honolulu"))
        .hasText("Yesterday", "4:00 PM the day before Lisbon's 2:00 AM");
    });

    test("time zones: offers each zone once, under its modern name", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();

      await select.search("kolkata");
      assert
        .dSelect()
        .hasOptions(["Asia/Kolkata"], "not also its old name, Asia/Calcutta");

      await select.search("ist");
      assert
        .dSelect()
        .hasNoOption("IST", "a bare abbreviation names no single zone");
    });

    test("time zones: groups zones by region, starting with the device's", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      await new DSelect().open();

      assert.deepEqual(headings().slice(0, 3), [
        "Your device's time zone",
        "Europe",
        "Africa",
      ]);
      assert.deepEqual(
        [...document.querySelectorAll(".d-select__panel [role='option']")]
          .slice(0, 3)
          .map((option) => option.dataset.value),
        ["Europe/Lisbon", "Europe/Amsterdam", "Europe/Andorra"],
        "the device's zone, then the device's region by city"
      );
    });

    test("time zones: lists UTC last, under its own heading", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      await new DSelect().open();
      await scrollToEnd();

      const options = [
        ...document.querySelectorAll(".d-select__panel [role='option']"),
      ];
      assert.strictEqual(options.at(-1).dataset.value, "UTC");
      assert.strictEqual(headings().at(-1), "UTC");
      assert
        .dom(row("UTC"))
        .includesText("Coordinated Universal Time", "UTC is named in full");
    });

    test("time zones: leaves the device's zone in its region when it is held", async function (assert) {
      await render(
        <template><DSelectTimezone @value="Europe/Lisbon" /></template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("lisbon");

      assert.dSelect().hasOptions(["Europe/Lisbon"]);
      assert.deepEqual(
        headings(),
        ["Europe"],
        "no shortcut to the zone already held"
      );
    });

    test("time zones: searches cities, countries, zone names and offsets", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();

      await select.search("são");
      assert.dSelect().hasOption("America/Sao_Paulo", "accents fold");

      await select.search("portugal");
      assert
        .dSelect()
        .hasOptions(
          ["Europe/Lisbon", "Atlantic/Azores", "Atlantic/Madeira"],
          "a country finds every zone in it"
        );

      await select.search("brasilia");
      assert.dSelect().hasOption("America/Sao_Paulo", "a zone name");

      await select.search("+5:30");
      assert
        .dSelect()
        .hasOptions(["Asia/Colombo", "Asia/Kolkata"], "an offset");

      await select.search("utc");
      assert
        .dSelect()
        .hasOptions(["UTC"], "UTC alone, not every offset spelt with it");

      await select.search("gmt");
      assert.dSelect().hasOptions(["UTC"], "GMT, as many call UTC");

      await select.search("utc-3");
      assert
        .dSelect()
        .hasOption("America/Sao_Paulo", "an offset spelt with UTC");
    });

    test("time zones: narrows by offset while it is still being typed", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();

      await select.search("utc+");
      assert.dSelect().hasOption("Europe/Lisbon", "GMT+0 is ahead or level");
      assert.dSelect().hasNoOption("America/Sao_Paulo", "GMT-3 is behind");

      await select.search("utc-");
      assert.dSelect().hasOption("America/Adak", "GMT-10 is behind");
      assert.dSelect().hasNoOption("Europe/Lisbon");

      await select.search("utc +5:30");
      assert
        .dSelect()
        .hasOptions(
          ["Asia/Colombo", "Asia/Kolkata"],
          "a space before the sign still reads as one offset"
        );
    });

    test("time zones: finds a zone by the name it shows, or any of its words", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();

      await select.search("Sao Paulo, Brazi");
      assert
        .dSelect()
        .hasOptions(["America/Sao_Paulo"], "the shown name, partly typed");

      await select.search("brazil paulo");
      assert.dSelect().hasOptions(["America/Sao_Paulo"], "words in any order");
    });

    test("time zones: a country finds the zones it shares with others", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("antigua");

      assert
        .dSelect()
        .hasOptions(
          ["America/Antigua", "America/Puerto_Rico"],
          "Puerto Rico's zone also serves Antigua"
        );
      assert
        .dom(".d-select-timezone__place", row("America/Puerto_Rico"))
        .hasText(
          "Puerto Rico",
          "named for its own country, which is also its city's name"
        );
    });

    test("time zones: names a zone that serves several countries by its own", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();

      await select.search("paris");
      assert
        .dom(".d-select-timezone__place", row("Europe/Paris"))
        .hasText("Paris, France", "not left bare because Monaco shares it");

      await select.search("tokyo");
      assert
        .dom(".d-select-timezone__place", row("Asia/Tokyo"))
        .hasText("Tokyo, Japan");
    });

    test("time zones: a held name the list doesn't offer still shows", async function (assert) {
      await render(
        <template><DSelectTimezone @value="Asia/Calcutta" /></template>
      );

      assert
        .dom(".d-select")
        .hasAttribute(
          "data-name",
          /^Calcutta\b/,
          "by its own city; whether a country follows depends on the browser's data"
        );
    });

    test("time zones: hands back the picked zone's name", async function (assert) {
      const value = tracked("UTC");
      const changes = [];
      const onChange = (zone) => {
        changes.push(zone);
        value.value = zone;
      };

      await render(
        <template>
          <DSelectTimezone @onChange={{onChange}} @value={{value.value}} />
        </template>
      );
      const select = new DSelect();
      await select.open();
      await select.search("lisbon");
      await select.select("Europe/Lisbon");

      assert.deepEqual(changes, ["Europe/Lisbon"]);
      assert.dSelect().hasName("Lisbon, Portugal");
    });

    test("time zones: the times are current each time the list opens", async function (assert) {
      await render(<template><DSelectTimezone /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("sao paulo");
      assert.dom(row("America/Sao_Paulo")).includesText("3:00 PM");
      await select.close();

      this.clock.tick(60 * 60 * 1000);
      await select.open();
      await select.search("sao paulo");

      assert.dom(row("America/Sao_Paulo")).includesText("4:00 PM");
    });

    test("time zones: names the field", async function (assert) {
      await render(<template><DSelectTimezone /></template>);

      assert.dom("[role='combobox']").hasAria("label", "Time zone");
    });

    test("time zones: the closed field shows the held zone's offset", async function (assert) {
      await render(
        <template><DSelectTimezone @value="America/Sao_Paulo" /></template>
      );

      assert.dSelect().hasName("Sao Paulo, Brazil");
      assert.dom(".d-select .d-select-timezone__offset").hasText("GMT-3");
    });

    test("time zones: a click into the field selects the held name, so typing replaces it", async function (assert) {
      await render(
        <template><DSelectTimezone @value="America/Sao_Paulo" /></template>
      );
      // A press flags itself on pointerdown, before the focus it causes.
      const input = document.querySelector(".d-select__input");
      await triggerEvent(input, "pointerdown");
      await focus(input);

      assert.strictEqual(input.value, "Sao Paulo, Brazil");
      assert.deepEqual(
        [input.selectionStart, input.selectionEnd],
        [0, input.value.length],
        "the whole name is selected"
      );
    });
  }
);
