import { longDate, updateRelativeAge } from "discourse/lib/formatter";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "boards-onebox-relative-dates",

  initialize() {
    withPluginApi((api) => {
      api.decorateCookedElement((elem) => {
        const dates = elem.querySelectorAll(
          ".discourse-boards-onebox__updated-at.relative-date[data-time]"
        );

        if (!dates.length) {
          return;
        }

        dates.forEach((el) => {
          const ts = parseInt(el.dataset.time, 10);
          if (ts) {
            el.title = longDate(new Date(ts));
          }
        });

        updateRelativeAge(dates);
      });
    });
  },
};
