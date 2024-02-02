import I18n from "discourse-i18n";
import emoji from "discourse/helpers/emoji";
import { fn, hash } from "@ember/helper";

const title = (description, endsAt, timezone) => {
  let title = description;
  if (endsAt) {
    const until = moment
      .tz(endsAt, timezone)
      .format(I18n.t("dates.long_date_without_year"));
    title += `\n${I18n.t("until")} ${until}`;
  }
  return title;
};

const UserStatusBubble = <template>
  <div class="user-status-background">
    {{emoji
      @status.emoji
      (hash title=(title @status.description @status.ends_at @timezone))
    }}
  </div>
</template>;

export default UserStatusBubble;
