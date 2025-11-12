import { hash } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

const VALID_REMINDERS = [
  {
    id: "daily",
    name: i18n("daily"),
  },
  {
    id: "weekly",
    name: i18n("weekly"),
  },
];

const PolicyReminderInput = <template>
  <ComboBox
    @value={{@reminder}}
    @content={{VALID_REMINDERS}}
    @options={{hash none="discourse_policy.builder.reminder.no_reminder"}}
    @onChange={{@onChangeReminder}}
  />
</template>;

export default PolicyReminderInput;
