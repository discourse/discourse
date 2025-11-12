import { concat } from "@ember/helper";
import emoji from "discourse/helpers/emoji";
import escape from "discourse/lib/escape";
import { i18n } from "discourse-i18n";

const title = (description, endsAt, timezone) => {
  let content = escape(description);

  if (endsAt) {
    const until = moment
      .tz(endsAt, timezone)
      .format(i18n("dates.long_date_without_year"));

    content += `\n${i18n("until")} ${until}`;
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
