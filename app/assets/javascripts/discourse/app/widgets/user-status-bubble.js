import { createWidget } from "discourse/widgets/widget";
import I18n from "I18n";

export default createWidget("user-status-bubble", {
  tagName: "div.user-status-background",

  html(attrs) {
    let title = attrs.description;
    if (attrs.ends_at) {
      const until = moment
        .tz(attrs.ends_at, this.currentUser.user_option.timezone)
        .format(I18n.t("dates.long_date_without_year"));
      title += `\n${I18n.t("until")} ${until}`;
    }

    return this.attach("emoji", { name: attrs.emoji, title });
  },
});
