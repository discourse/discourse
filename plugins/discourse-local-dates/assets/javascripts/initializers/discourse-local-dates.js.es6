import deprecated from "discourse-common/lib/deprecated";
import { getOwner } from "discourse-common/lib/get-owner";
import { hidePopover, showPopover } from "discourse/lib/d-popover";
import LocalDateBuilder from "../lib/local-date-builder";
import { withPluginApi } from "discourse/lib/plugin-api";
import showModal from "discourse/lib/show-modal";

export function applyLocalDates(dates, siteSettings) {
  if (!siteSettings.discourse_local_dates_enabled) {
    return;
  }

  const currentUserTZ = moment.tz.guess();

  dates.forEach((element) => {
    const opts = buildOptionsFromElement(element, siteSettings);

    const localDateBuilder = new LocalDateBuilder(opts, currentUserTZ).build();
    element.innerText = "";
    element.insertAdjacentHTML(
      "beforeend",
      `
        <svg class="fa d-icon d-icon-globe-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
          <use xlink:href="#globe-americas"></use>
        </svg>
        <span class="relative-time">${localDateBuilder.formated}</span>
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

function _rangeElements(element) {
  if (!element.parentElement) {
    return [];
  }
  return Array.from(element.parentElement.children).filter(
    (span) => span.dataset.date
  );
}

function initializeDiscourseLocalDates(api) {
  const siteSettings = api.container.lookup("site-settings:main");
  const chat = api.container.lookup("service:chat");

  if (chat) {
    chat.addToolbarButton({
      title: "discourse_local_dates.title",
      id: "local-dates",
      icon: "calendar-alt",
      action: "insertDiscourseLocalDate",
    });

    api.modifyClass("component:chat-composer", {
      pluginId: "discourse-local-dates",
      actions: {
        insertDiscourseLocalDate() {
          const insertDate = this.addText.bind(this);
          showModal("discourse-local-dates-create-modal").setProperties({
            insertDate,
          });
        },
      },
    });
  }

  api.decorateCookedElement(
    (elem) => {
      applyLocalDates(
        elem.querySelectorAll(".discourse-local-date"),
        siteSettings
      );
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
    dateTimeNode.innerHTML = preview.formated;
    previewNode.appendChild(dateTimeNode);

    return previewNode;
  });

  const previewsNode = document.createElement("div");
  previewsNode.classList.add("locale-dates-previews");
  htmlPreviews.forEach((htmlPreview) => previewsNode.appendChild(htmlPreview));

  return previewsNode.outerHTML;
}

function _calculateDuration(element) {
  const [startDataset, endDataset] = _rangeElements(element).map(
    (dateElement) => dateElement.dataset
  );
  const startDateTime = moment(
    `${startDataset.date} ${startDataset.time || ""}`
  );
  const endDateTime = moment(`${endDataset.date} ${endDataset.time || ""}`);
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

    const siteSettings = owner.lookup("site-settings:main");
    if (event?.target?.classList?.contains("discourse-local-date")) {
      if ($(document.getElementById("d-popover"))[0]) {
        hidePopover(event);
      } else {
        showPopover(event, {
          htmlContent: buildHtmlPreview(event.target, siteSettings),
        });
      }
    }
  },

  hideDatePopover(event) {
    if (event?.target?.classList?.contains("discourse-local-date")) {
      hidePopover(event);
    }
  },

  initialize(container) {
    const router = container.lookup("router:main");
    router.on("routeWillChange", hidePopover);

    window.addEventListener("click", this.showDatePopover);
    window.addEventListener("mouseout", this.hideDatePopover);

    const siteSettings = container.lookup("site-settings:main");
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
    window.removeEventListener("mouseout", this.hideDatePopover);
  },
};
