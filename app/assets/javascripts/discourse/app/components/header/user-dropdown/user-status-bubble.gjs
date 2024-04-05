import { hash } from "@ember/helper";
import emoji from "discourse/helpers/emoji";
import I18n from "discourse-i18n";

const title = (description, endsAt, timezone) => {
  let content = description;
  if (endsAt) {
    const until = moment
      .tz(endsAt, timezone)
      .format(I18n.t("dates.long_date_without_year"));
    content += `\n${I18n.t("until")} ${until}`;
  }
  return content;
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
