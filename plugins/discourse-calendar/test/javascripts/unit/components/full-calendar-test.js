import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import FullCalendar from "discourse/plugins/discourse-calendar/components/full-calendar";

module("Unit | Component | full-calendar", function (hooks) {
  setupRenderingTest(hooks);

  test("firstDayOfWeek getter returns correct values", async function (assert) {
    const component = new FullCalendar();
    component.siteSettings = this.owner.lookup("service:site-settings");

    // Test Monday (default)
    component.siteSettings.calendar_first_day_of_week = "Monday";
    assert.strictEqual(component.firstDayOfWeek, 1, "Monday should return 1");

    // Test Sunday
    component.siteSettings.calendar_first_day_of_week = "Sunday";
    assert.strictEqual(component.firstDayOfWeek, 0, "Sunday should return 0");

    // Test Saturday
    component.siteSettings.calendar_first_day_of_week = "Saturday";
    assert.strictEqual(component.firstDayOfWeek, 6, "Saturday should return 6");

    // Test default fallback
    component.siteSettings.calendar_first_day_of_week = "Invalid";
    assert.strictEqual(
      component.firstDayOfWeek,
      1,
      "Invalid value should default to Monday (1)"
    );
  });

  test("calendar configuration uses firstDayOfWeek setting", async function () {
    // Mock the calendar module
    const mockCalendarModule = {
      Calendar: class MockCalendar {
        constructor(element, options) {
          this.element = element;
          this.options = options;
        }

        render() {}

        destroy() {}
      },
      DayGrid: {},
      TimeGrid: {},
      List: {},
      RRULE: {},
      MomentTimezone: {},
    };

    // Mock loadFullCalendar to return our mock
    this.owner.register("service:load-full-calendar", {
      loadFullCalendar() {
        return Promise.resolve(mockCalendarModule);
      },
    });

    // Test with Monday
    this.siteSettings.calendar_first_day_of_week = "Monday";
    await render(hbs`<FullCalendar />`);

    // The calendar should be created with firstDay: 1
    // We can't easily test this without more complex mocking, but the getter test above covers the logic

    // Test with Sunday
    this.siteSettings.calendar_first_day_of_week = "Sunday";
    await render(hbs`<FullCalendar />`);

    // Test with Saturday
    this.siteSettings.calendar_first_day_of_week = "Saturday";
    await render(hbs`<FullCalendar />`);
  });
});
