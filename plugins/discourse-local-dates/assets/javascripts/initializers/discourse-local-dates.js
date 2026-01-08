import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { bbcodeAttributeDecode } from "discourse/lib/bbcode-attributes";
import { bind } from "discourse/lib/decorators";
import { downloadCalendar } from "discourse/lib/download-calendar";
import { iconHTML, renderIcon } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  addTagDecorateCallback,
  addTextDecorateCallback,
} from "discourse/lib/to-markdown";
import { slugify } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import generateDateMarkup from "discourse/plugins/discourse-local-dates/lib/local-date-markup-generator";
import LocalDatesCreateModal from "../discourse/components/modal/local-dates-create";
import generateCurrentDateMarkup from "../lib/generate-current-date-markup";
import LocalDateBuilder from "../lib/local-date-builder";
import richEditorExtension from "../lib/rich-editor-extension";

// Import applyLocalDates from discourse/lib/local-dates instead
export function applyLocalDates(dates, siteSettings, profileTimezone) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  const browserTimezone = moment.tz.guess();

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

    const localDateBuilder = new LocalDateBuilder(opts, browserTimezone, {
      profileTimezone,
    }).build();

    element.innerText = "";
    element.insertAdjacentHTML(
      "beforeend",
      `${iconHTML("earth-americas")}
        <span class="relative-time">${localDateBuilder.formatted}</span>`
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
  opts.displayedTimezone = dataset.displayedTimezone;
  opts.format = dataset.format || (opts.time ? "LLL" : "LL");
  opts.countdown = dataset.countdown;
  opts.calendar = dataset.calendar
    ? dataset.calendar === "on"
    : !dataset.format;
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
  api.registerRichEditorExtension(richEditorExtension);

  const modal = api.container.lookup("service:modal");
  const siteSettings = api.container.lookup("service:site-settings");
  const defaultTitle = i18n("discourse_local_dates.default_title", {
    site_name: siteSettings.title,
  });

  api.decorateCookedElement((elem, helper) => {
    const dates = elem.querySelectorAll(".discourse-local-date");
    const currentUser = api.getCurrentUser();

    applyLocalDates(dates, siteSettings, currentUser?.user_option?.timezone);

    const topicTitle = helper?.getModel()?.topic?.title;
    dates.forEach((date) => {
      date.dataset.title = date.dataset.title || topicTitle || defaultTitle;
    });
  });

  api.addComposerToolbarPopupMenuOption({
    name: "local-dates",
    label: "discourse_local_dates.title",
    icon: "far-clock",
    action: (event) =>
      modal.show(LocalDatesCreateModal, {
        model: { insertDate: (markup) => event.addText(markup) },
      }),
    shortcut: "Shift+.",
    alwaysShowShortcut: true,
    shortcutAction: (event) => {
      const timezone = api.getCurrentUser().user_option.timezone;
      event.addText(generateCurrentDateMarkup(timezone));
    },
  });

  addTextDecorateCallback(
    function (text, nextElement, _previousElement, metadata) {
      if (
        metadata.discourseLocalDateStartRangeOpts &&
        nextElement?.attributes.class?.includes("discourse-local-date") &&
        text === "→"
      ) {
        return "";
      }
    }
  );
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

function buildHtmlPreview(element, siteSettings, profileTimezone) {
  const opts = buildOptionsFromElement(element, siteSettings);
  const localDateBuilder = new LocalDateBuilder(opts, moment.tz.guess(), {
    profileTimezone,
  }).build();

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
  node.innerHTML = `${renderIcon("string", "file")} ${i18n(
    "download_calendar.add_to_calendar"
  )}`;
  node.setAttribute("data-starts-at", startDate.toISOString());
  if (endDataset) {
    node.setAttribute("data-ends-at", endDate.toISOString());
  }
  if (!startDataset.time && !endDataset) {
    node.setAttribute("data-ends-at", startDate.add(24, "hours").toISOString());
  }
  if (startDataset.title) {
    node.setAttribute("data-title", startDataset.title);
  }
  if (startDataset.timezone) {
    node.setAttribute("data-timezone", startDataset.timezone);
  }

  // If ics data is available, pass it to the download button
  if (startDataset.ics) {
    node.setAttribute("data-ics", startDataset.ics);
  }

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

class LocalDatesInit {
  @service currentUser;
  @service siteSettings;
  @service tooltip;

  constructor(owner) {
    setOwner(this, owner);

    window.addEventListener("click", this.showDatePopover, { passive: true });

    if (this.siteSettings.discourse_local_dates_enabled) {
      withPluginApi(initializeDiscourseLocalDates);
    }
  }

  @bind
  showDatePopover(event) {
    if (event?.target?.classList?.contains("download-calendar")) {
      const dataset = event.target.dataset;

      if (dataset.ics) {
        const icsData = bbcodeAttributeDecode(dataset.ics);

        let title;
        if (dataset.title) {
          title = dataset.title;
        } else {
          // Extract event title from ICS SUMMARY field for filename if title missing
          const summaryMatch = icsData.match(/SUMMARY:(.+?)[\r\n]/);
          if (summaryMatch && summaryMatch[1]) {
            title = summaryMatch[1].trim();
          }
        }

        this.downloadIcs(title || "event", icsData);
      } else {
        const dates = [
          {
            startsAt: dataset.startsAt,
            endsAt: dataset.endsAt,
          },
        ];

        // Add timezone if available
        if (dataset.timezone) {
          dates[0].timezone = dataset.timezone;
        }

        downloadCalendar(dataset.title, dates);
      }

      return this.tooltip.close("local-date");
    }

    if (!event?.target?.classList?.contains("discourse-local-date")) {
      return;
    }

    return this.tooltip.show(event.target, {
      identifier: "local-date",
      content: htmlSafe(
        buildHtmlPreview(
          event.target,
          this.siteSettings,
          this.currentUser?.user_option?.timezone
        )
      ),
    });
  }

  downloadIcs(title, icsData) {
    const blob = new Blob([icsData], { type: "text/calendar;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    try {
      const a = document.createElement("a");
      a.href = url;
      const fileName = slugify(title);
      a.download = `${fileName}.ics`;
      // Most browsers allow clicking without attaching to DOM.
      a.click();
    } finally {
      // Revoke on next tick so the download can start.
      setTimeout(() => URL.revokeObjectURL(url), 0);
    }
  }

  teardown() {
    window.removeEventListener("click", this.showDatePopover);
  }
}

export default {
  initialize(owner) {
    this.instance = new LocalDatesInit(owner);
  },
  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
