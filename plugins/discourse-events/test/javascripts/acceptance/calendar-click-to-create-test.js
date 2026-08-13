import { click, settled, visit, waitFor } from "@ember/test-helpers";
import moment from "moment";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function noEventsPretender(server, helper) {
  server.get("/discourse-post-event/events", () => {
    return helper.response({ events: [] });
  });
}

const SETTINGS = {
  calendar_enabled: true,
  discourse_post_event_enabled: true,
  events_calendar_categories: "1",
  calendar_categories: "",
};

function todayCellDate() {
  return document.querySelector(".fc-day-today").getAttribute("data-date");
}

function cellFor(date) {
  return document.querySelector(`.fc-daygrid-day[data-date="${date}"]`);
}

function fireMouse(type, target, x, y) {
  target.dispatchEvent(
    new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      view: window,
      clientX: x,
      clientY: y,
    })
  );
}

// Simulates a FullCalendar click-and-drag day selection by dispatching the
// pointer sequence (mousedown -> mousemove -> mouseup) the interaction plugin
// listens for, using the centers of the start and end day cells.
async function dragSelect(startEl, endEl) {
  const start = startEl.getBoundingClientRect();
  const end = endEl.getBoundingClientRect();
  const startX = start.left + start.width / 2;
  const startY = start.top + start.height / 2;
  const endX = end.left + end.width / 2;
  const endY = end.top + end.height / 2;

  fireMouse("mousedown", startEl, startX, startY);
  fireMouse("mousemove", document, startX + 5, startY + 5);
  fireMouse("mousemove", endEl, endX, endY);
  fireMouse("mouseup", document, endX, endY);

  await settled();
}

// Simulates a FullCalendar click-and-drag selection down the time axis of a
// timegrid column, from the top of the start slot to the top of the end slot.
async function dragSelectTime(colEl, startSlotEl, endSlotEl) {
  const col = colEl.getBoundingClientRect();
  const startSlot = startSlotEl.getBoundingClientRect();
  const endSlot = endSlotEl.getBoundingClientRect();
  const x = col.left + col.width / 2;
  const startY = startSlot.top + 1;
  const endY = endSlot.top + 1;

  fireMouse("mousedown", startSlotEl, x, startY);
  fireMouse("mousemove", document, x, startY + 5);
  fireMouse("mousemove", endSlotEl, x, endY);
  fireMouse("mouseup", document, x, endY);

  await settled();
}

acceptance(
  "Calendar click to create - upcoming events (with permission)",
  function (needs) {
    needs.user({ can_create_discourse_post_event: true });
    needs.settings(SETTINGS);
    needs.pretender(noEventsPretender);

    test("clicking an empty day cell opens the composer with an all-day event at 9am", async function (assert) {
      await visit("/upcoming-events");
      await waitFor(".fc-day-today");

      const date = todayCellDate();
      const nextDate = moment(date).add(1, "day").format("YYYY-MM-DD");

      await click(".fc-day-today");
      await waitFor(".d-editor-input");

      assert
        .dom(".discard-draft-modal")
        .doesNotExist("discard modal does not appear on a single click");

      assert
        .dom(".d-editor-input")
        .hasValue(
          new RegExp(
            `^\\[event start="${date} 09:00" status="public" timezone="[^"]+" end="${nextDate} 00:00" allDay=true\\]\\n\\[/event\\]\\n$`
          ),
          "composer opens with an all-day event defaulting to 9am for the clicked day"
        );
    });

    test("dragging across multiple day cells opens the composer with a multi-day all-day event", async function (assert) {
      await visit("/upcoming-events");
      await waitFor(".fc-day-today");

      const startDate = todayCellDate();
      const lastDate = moment(startDate).add(2, "days").format("YYYY-MM-DD");
      // the selection end is exclusive, so a 3-day selection ends on the 4th day
      const endDate = moment(startDate).add(3, "days").format("YYYY-MM-DD");

      await dragSelect(cellFor(startDate), cellFor(lastDate));
      await waitFor(".d-editor-input");

      assert
        .dom(".d-editor-input")
        .hasValue(
          new RegExp(
            `^\\[event start="${startDate} 09:00" status="public" timezone="[^"]+" end="${endDate} 00:00" allDay=true\\]\\n\\[/event\\]\\n$`
          ),
          "composer opens with an all-day event spanning the dragged range"
        );
    });

    test("dragging across hours in the day view opens the composer with a timed event", async function (assert) {
      await visit("/upcoming-events");
      await waitFor(".fc-day-today");

      await click(".fc-timeGridDay-button");
      await waitFor(".fc-timegrid-slot-lane");

      const col = document.querySelector(".fc-timegrid-col.fc-day-today");
      const date = col.getAttribute("data-date");

      // FullCalendar's selection end is exclusive of the released slot's start,
      // so releasing on the 11:30 slot produces a selection ending at 12:00.
      await dragSelectTime(
        col,
        document.querySelector(".fc-timegrid-slot-lane[data-time='09:00:00']"),
        document.querySelector(".fc-timegrid-slot-lane[data-time='11:30:00']")
      );
      await waitFor(".d-editor-input");

      assert
        .dom(".d-editor-input")
        .hasValue(
          new RegExp(
            `^\\[event start="${date} 09:00" status="public" timezone="[^"]+" end="${date} 12:00"\\]\\n\\[/event\\]\\n$`
          ),
          "composer opens with a timed 9am-12pm event and no allDay flag"
        );
    });
  }
);

acceptance(
  "Calendar click to create - category (with permission)",
  function (needs) {
    needs.user({ can_create_discourse_post_event: true });
    needs.settings(SETTINGS);
    needs.pretender(noEventsPretender);

    test("clicking an empty day cell opens the composer prefilled with the category", async function (assert) {
      await visit("/c/bug/1");
      await waitFor(".fc-day-today");

      const date = todayCellDate();
      const nextDate = moment(date).add(1, "day").format("YYYY-MM-DD");

      await click(".fc-day-today");
      await waitFor(".d-editor-input");

      assert
        .dom(".discard-draft-modal")
        .doesNotExist("discard modal does not appear on a single click");

      assert
        .dom(".d-editor-input")
        .hasValue(
          new RegExp(
            `^\\[event start="${date} 09:00" status="public" timezone="[^"]+" end="${nextDate} 00:00" allDay=true\\]\\n\\[/event\\]\\n$`
          ),
          "composer opens with an all-day event for the clicked day"
        );

      assert.strictEqual(
        selectKit(".category-chooser").header().value(),
        "1",
        "the calendar's category is preselected in the composer"
      );
    });
  }
);

acceptance("Calendar click to create - no permission", function (needs) {
  needs.user({ can_create_discourse_post_event: false });
  needs.settings(SETTINGS);
  needs.pretender(noEventsPretender);

  test("clicking an empty day cell does nothing without event-create permission", async function (assert) {
    await visit("/upcoming-events");
    await waitFor(".fc-day-today");

    await click(".fc-day-today");

    assert
      .dom(".d-editor-input")
      .doesNotExist(
        "composer does not open when the user cannot create events"
      );
  });
});
