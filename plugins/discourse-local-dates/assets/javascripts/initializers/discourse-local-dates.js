import deprecated from "discourse-common/lib/deprecated";
import { getOwner } from "discourse-common/lib/get-owner";
import LocalDateBuilder from "../lib/local-date-builder";
import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";
import { downloadCalendar } from "discourse/lib/download-calendar";
import { renderIcon } from "discourse-common/lib/icon-library";
import I18n from "I18n";
import { hidePopover, showPopover } from "discourse/lib/d-popover";
import {
  addTagDecorateCallback,
  addTextDecorateCallback,
} from "discourse/lib/to-markdown";
import generateDateMarkup from "discourse/plugins/discourse-local-dates/lib/local-date-markup-generator";

// Import applyLocalDates from discourse/lib/local-dates instead
export function applyLocalDates(dates, siteSettings) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  const currentUserTZ = moment.tz.guess();

  dates.forEach((element, index, arr) => {
    const opts = buildOptionsFromElement(element, siteSettings);

    if (
      element.attributes["data-range"]?.value === "to" &&
      index !== 0 &&
      arr[index - 1].attributes["data-range"]?.value === "from"
    ) {
      const fromElement = arr[index - 1];
      if (_rangeIsSameLocalDay(fromElement, element)) {
        opts.sameLocalDayAsFrom = true;
      }
    }

    const localDateBuilder = new LocalDateBuilder(opts, currentUserTZ).build();

    element.innerText = "";
    element.insertAdjacentHTML(
      "beforeend",
      `
        <svg class="fa d-icon d-icon-globe-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
          <use href="#globe-americas"></use>
        </svg>
        <span class="relative-time">${localDateBuilder.formatted}</span>
      `
    );
    element.setAttribute("aria-label", localDateBuilder.textPreview);

    const classes = ["cooked-date"];
    if (localDateBuilder.pastEvent) {
      classes.push("past");
    }
    element.classList.add(...classes);
  });
}

function _rangeIsSameLocalDay(fromElement, toElement) {
  if (
    !fromElement.attributes["data-time"] ||
    !toElement.attributes["data-time"]
  ) {
    return false;
  }
  const timezone = fromElement.attributes["data-timezone"].value;
  const from = moment(_getDateFromElement(fromElement)).tz(timezone);
  const to = moment(_getDateFromElement(toElement)).tz(timezone);
  return from.isSame(to, "day");
}

function _getDateFromElement(element) {
  return `${element.attributes["data-date"].value}T${element.attributes["data-time"].value}`;
}

function buildOptionsFromElement(element, siteSettings) {
  const opts = {};
  const dataset = element.dataset;

  if (_rangeElements(element).length === 2) {
    opts.duration = _calculateDuration(element);
  }

  opts.time = dataset.time;
  opts.date = dataset.date;
  opts.recurring = dataset.recurring;
  opts.timezones = (
    dataset.timezones ||
    siteSettings.discourse_local_dates_default_timezones ||
    "Etc/UTC"
  )
    .split("|")
    .filter(Boolean);
  opts.timezone = dataset.timezone;
  opts.calendar = (dataset.calendar || "on") === "on";
  opts.displayedTimezone = dataset.displayedTimezone;
  opts.format = dataset.format || (opts.time ? "LLL" : "LL");
  opts.countdown = dataset.countdown;
  return opts;
}

function buildOptionsFromMarkdownTag(element) {
  const opts = {};

  // siteSettings defaults as used by buildOptionsFromElement are purposefully
  // ommitted to reproduce exactly what was on the original element
  opts.time = element.attributes["data-time"];
  opts.date = element.attributes["data-date"];
  opts.recurring = element.attributes["data-recurring"];
  opts.timezones = element.attributes["data-timezones"];
  opts.timezone = element.attributes["data-timezone"];
  opts.calendar = (element.attributes["data-calendar"] || "on") === "on";
  opts.displayedTimezone = element.attributes["data-displayed-timezone"];
  opts.format = element.attributes["data-format"];
  opts.countdown = element.attributes["data-countdown"];
  opts.range = element.attributes["data-range"];

  return opts;
}

function _rangeElements(element) {
  if (!element.parentElement) {
    return [];
  }

  if (element.dataset.range) {
    return _partitionedRanges(element).find((pair) => pair.includes(element));
  }

  return [element];
}

function _partitionedRanges(element) {
  const partitions = [];
  const ranges = Array.from(element.parentElement.children).filter(
    (span) => span.dataset.range
  );

  while (ranges.length > 0) {
    partitions.push(ranges.splice(0, 2));
  }

  return partitions;
}

function initializeDiscourseLocalDates(api) {
  const siteSettings = api.container.lookup("service:site-settings");
  const defaultTitle = I18n.t("discourse_local_dates.default_title", {
    site_name: siteSettings.title,
  });

  api.decorateCookedElement(
    (elem, helper) => {
      const dates = elem.querySelectorAll(".discourse-local-date");

      applyLocalDates(dates, siteSettings);

      const topicTitle = helper?.getModel()?.topic?.title;
      dates.forEach((date) => {
        date.dataset.title = date.dataset.title || topicTitle || defaultTitle;
      });
    },
    { id: "discourse-local-date" }
  );

  api.onToolbarCreate((toolbar) => {
    toolbar.addButton({
      title: "discourse_local_dates.title",
      id: "local-dates",
      group: "extras",
      icon: "calendar-alt",
      sendAction: (event) =>
        toolbar.context.send("insertDiscourseLocalDate", event),
    });
  });

  api.modifyClass("component:d-editor", {
    pluginId: "discourse-local-dates",
    actions: {
      insertDiscourseLocalDate(toolbarEvent) {
        showModal("discourse-local-dates-create-modal").setProperties({
          insertDate: (markup) => {
            toolbarEvent.addText(markup);
          },
        });
      },
    },
  });

  addTextDecorateCallback(function (
    text,
    nextElement,
    _previousElement,
    metadata
  ) {
    if (
      metadata.discourseLocalDateStartRangeOpts &&
      nextElement?.attributes.class?.includes("discourse-local-date") &&
      text === "→"
    ) {
      return "";
    }
  });
  addTagDecorateCallback(function () {
    if (this.element.attributes.class?.includes("discourse-local-date")) {
      if (this.metadata.discourseLocalDateStartRangeOpts) {
        const startRangeOpts = this.metadata.discourseLocalDateStartRangeOpts;
        const endRangeOpts = buildOptionsFromMarkdownTag(this.element);
        const markup = generateDateMarkup(
          {
            date: startRangeOpts.date,
            time: startRangeOpts.time,
            format: startRangeOpts.format,
          },
          endRangeOpts,
          true,
          {
            date: endRangeOpts.date,
            time: endRangeOpts.time,
            format: endRangeOpts.format,
          }
        );
        this.prefix = markup;
        this.metadata.discourseLocalDateStartRangeOpts = null;
        return "";
      }
      if (
        this.element.attributes["data-range"] === "true" ||
        this.element.attributes["data-range"] === "from" ||
        this.element.attributes["data-range"] === "to"
      ) {
        this.metadata.discourseLocalDateStartRangeOpts =
          buildOptionsFromMarkdownTag(this.element);
        return "";
      }
      const opts = buildOptionsFromMarkdownTag(this.element, siteSettings);
      const markup = generateDateMarkup(
        { date: opts.date, time: opts.time, format: opts.format },
        opts,
        false
      );
      this.prefix = markup;
      return "";
    }
  });
}

function buildHtmlPreview(element, siteSettings) {
  const opts = buildOptionsFromElement(element, siteSettings);
  const localDateBuilder = new LocalDateBuilder(
    opts,
    moment.tz.guess()
  ).build();

  const htmlPreviews = localDateBuilder.previews.map((preview) => {
    const previewNode = document.createElement("div");
    previewNode.classList.add("preview");
    if (preview.current) {
      previewNode.classList.add("current");
    }

    const timezoneNode = document.createElement("span");
    timezoneNode.classList.add("timezone");
    timezoneNode.innerText = preview.timezone;
    previewNode.appendChild(timezoneNode);

    const dateTimeNode = document.createElement("span");
    dateTimeNode.classList.add("date-time");
    dateTimeNode.innerHTML = preview.formatted;
    previewNode.appendChild(dateTimeNode);

    return previewNode;
  });

  const previewsNode = document.createElement("div");
  previewsNode.classList.add("locale-dates-previews");
  htmlPreviews.forEach((htmlPreview) => previewsNode.appendChild(htmlPreview));

  const calendarNode = _downloadCalendarNode(element);
  if (calendarNode) {
    previewsNode.appendChild(calendarNode);
  }

  return previewsNode.outerHTML;
}

function calculateStartAndEndDate(startDataset, endDataset) {
  let startDate, endDate;
  startDate = moment.tz(
    `${startDataset.date} ${startDataset.time || ""}`.trim(),
    startDataset.timezone
  );
  if (endDataset) {
    endDate = moment.tz(
      `${endDataset.date} ${endDataset.time || ""}`.trim(),
      endDataset.timezone
    );
  }
  return [startDate, endDate];
}

function _downloadCalendarNode(element) {
  const [startDataset, endDataset] = _rangeElements(element).map(
    (dateElement) => dateElement.dataset
  );
  const [startDate, endDate] = calculateStartAndEndDate(
    startDataset,
    endDataset
  );

  if (startDate < moment().tz(startDataset.timezone)) {
    return false;
  }

  const node = document.createElement("div");
  node.classList.add("download-calendar");
  node.innerHTML = `${renderIcon("string", "file")} ${I18n.t(
    "download_calendar.add_to_calendar"
  )}`;
  node.setAttribute("data-starts-at", startDate.toISOString());
  if (endDataset) {
    node.setAttribute("data-ends-at", endDate.toISOString());
  }
  if (!startDataset.time && !endDataset) {
    node.setAttribute("data-ends-at", startDate.add(24, "hours").toISOString());
  }
  node.setAttribute("data-title", startDataset.title);
  return node;
}

function _calculateDuration(element) {
  const [startDataset, endDataset] = _rangeElements(element).map(
    (dateElement) => dateElement.dataset
  );
  const startDateTime = moment(
    `${startDataset.date} ${startDataset.time || ""}`.trim()
  );
  const endDateTime = moment(
    `${endDataset.date} ${endDataset.time || ""}`.trim()
  );
  const duration = endDateTime.diff(startDateTime, "minutes");

  // negative duration is used when we calculate difference for end date from range
  return element.dataset === startDataset ? duration : -duration;
}

export default {
  name: "discourse-local-dates",

  showDatePopover(event) {
    const owner = getOwner(this);
    if (owner.isDestroyed || owner.isDestroying) {
      return;
    }

    if (event?.target?.classList?.contains("download-calendar")) {
      const dataset = event.target.dataset;
      downloadCalendar(dataset.title, [
        {
          startsAt: dataset.startsAt,
          endsAt: dataset.endsAt,
        },
      ]);

      // TODO: remove this when rewriting preview as a component
      const parentPopover = event.target.closest("[data-tippy-root]");
      if (parentPopover?._tippy) {
        parentPopover._tippy.hide();
      }

      return;
    }

    if (!event?.target?.classList?.contains("discourse-local-date")) {
      return;
    }

    const siteSettings = owner.lookup("service:site-settings");

    showPopover(event, {
      trigger: "click",
      content: buildHtmlPreview(event.target, siteSettings),
      allowHTML: true,
      interactive: true,
      appendTo: "parent",
      onHidden: (instance) => {
        instance.destroy();
      },
    });
  },

  hideDatePopover(event) {
    hidePopover(event);
  },

  initialize(container) {
    window.addEventListener("click", this.showDatePopover);

    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_local_dates_enabled) {
      $.fn.applyLocalDates = function () {
        deprecated(
          "`$.applyLocalDates()` is deprecated, import and use `applyLocalDates()` instead."
        );

        return applyLocalDates(this.toArray(), siteSettings);
      };

      withPluginApi("0.8.8", initializeDiscourseLocalDates);
    }
  },

  teardown() {
    window.removeEventListener("click", this.showDatePopover);
  },
};
