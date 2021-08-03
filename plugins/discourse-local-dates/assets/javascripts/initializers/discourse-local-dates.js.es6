import LocalDateBuilder from "../lib/local-date-builder";
import showModal from "discourse/lib/show-modal";
import { withPluginApi } from "discourse/lib/plugin-api";

function initializeDiscourseLocalDates(api) {
  api.decorateCooked(
    ($elem) => $(".discourse-local-date", $elem).applyLocalDates(),
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
    actions: {
      insertDiscourseLocalDate(toolbarEvent) {
        showModal("discourse-local-dates-create-modal").setProperties({
          toolbarEvent,
        });
      },
    },
  });
}

export default {
  name: "discourse-local-dates",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_local_dates_enabled) {
      const currentUserTZ = moment.tz.guess();

      $.fn.applyLocalDates = function () {
        return this.each(function () {
          const opts = {};
          const dataset = this.dataset;
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

          const localDateBuilder = new LocalDateBuilder(
            opts,
            currentUserTZ
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
            dateTimeNode.innerText = preview.formated;
            previewNode.appendChild(dateTimeNode);

            return previewNode;
          });

          const previewsNode = document.createElement("div");
          previewsNode.classList.add("locale-dates-previews");
          htmlPreviews.forEach((htmlPreview) =>
            previewsNode.appendChild(htmlPreview)
          );

          this.innerText = "";
          this.insertAdjacentHTML(
            "beforeend",
            `
              <svg class="fa d-icon d-icon-globe-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
                <use xlink:href="#globe-americas"></use>
              </svg>
              <span class="relative-time">${localDateBuilder.formated}</span>
            `
          );
          this.setAttribute("aria-label", localDateBuilder.textPreview);
          this.dataset.htmlTooltip = previewsNode.outerHTML;

          const classes = ["cooked-date"];
          if (localDateBuilder.pastEvent) {
            classes.push("past");
          }
          this.classList.add(...classes);
        });
      };

      withPluginApi("0.8.8", initializeDiscourseLocalDates);
    }
  },
};
