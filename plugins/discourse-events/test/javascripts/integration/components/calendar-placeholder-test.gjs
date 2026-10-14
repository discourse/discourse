import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CalendarPlaceholder from "discourse/plugins/discourse-events/discourse/components/calendar-placeholder";

module("Integration | Component | CalendarPlaceholder", function (hooks) {
  setupRenderingTest(hooks);

  test("month view renders six weeks of day cells", async function (assert) {
    await render(
      <template><CalendarPlaceholder @view="dayGridMonth" /></template>
    );

    assert.dom(".calendar-placeholder.--month").exists();
    assert.dom(".calendar-placeholder__day").exists({ count: 42 });
  });

  test("month view drops weekend columns when weekends are hidden", async function (assert) {
    await render(
      <template>
        <CalendarPlaceholder @view="dayGridMonth" @weekends={{false}} />
      </template>
    );

    assert.dom(".calendar-placeholder__day").exists({ count: 30 });
  });

  test("week view renders a time grid with a column per day", async function (assert) {
    await render(
      <template><CalendarPlaceholder @view="timeGridWeek" /></template>
    );

    assert.dom(".calendar-placeholder.--time-grid").exists();
    assert.dom(".calendar-placeholder__column").exists({ count: 7 });
  });

  test("day view renders a single time grid column", async function (assert) {
    await render(
      <template><CalendarPlaceholder @view="timeGridDay" /></template>
    );

    assert.dom(".calendar-placeholder__column").exists({ count: 1 });
  });

  test("list view renders list rows", async function (assert) {
    await render(<template><CalendarPlaceholder @view="listYear" /></template>);

    assert.dom(".calendar-placeholder.--list").exists();
    assert.dom(".calendar-placeholder__list-row").exists();
  });

  test("applies a valid height and ignores an invalid one", async function (assert) {
    await render(<template><CalendarPlaceholder @height="650px" /></template>);
    assert.dom(".calendar-placeholder").hasStyle({ height: "650px" });

    await render(
      <template><CalendarPlaceholder @height="650px; color: red" /></template>
    );
    assert
      .dom(".calendar-placeholder")
      .hasAttribute("style", "--calendar-placeholder-columns: 7");
  });
});
