import { concat } from "@ember/helper";
import emoji from "discourse/helpers/emoji";
import escape from "discourse-common/lib/escape";
import I18n from "discourse-i18n";

const title = (description, endsAt, timezone) => {
  let content = escape(description);

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
      title=(title @status.description @status.ends_at @timezone)
      alt=(concat ":" @status.emoji ":")
    }}
  </div>
</template>;

export default UserStatusBubble;
