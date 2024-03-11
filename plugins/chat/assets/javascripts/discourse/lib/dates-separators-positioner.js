import { schedule } from "@ember/runloop";

export default class DatesSeparatorsPositioner {
  static apply(list) {
    schedule("afterRender", () => {
      const dates = [
        ...list.querySelectorAll(".chat-message-separator-date"),
      ].reverse();
      const height = list.querySelector(
        ".chat-messages-container"
      ).clientHeight;

      dates
        .map((date, index) => {
          const item = { bottom: 0, date };
          const line = date.nextElementSibling;

          if (index > 0) {
            const prevDate = dates[index - 1];
            const prevLine = prevDate.nextElementSibling;
            item.bottom = height - prevLine.offsetTop;
          }

          if (dates.length === 1) {
            item.height = height;
          } else {
            if (index === 0) {
              item.height = height - line.offsetTop;
            } else {
              const prevDate = dates[index - 1];
              const prevLine = prevDate.nextElementSibling;
              item.height =
                height - line.offsetTop - (height - prevLine.offsetTop);
            }
          }

          return item;
        })
        // group all writes at the end
        .forEach((item) => {
          item.date.style.bottom = item.bottom + "px";
          item.date.style.height = item.height + "px";
        });
    });
  }
}
