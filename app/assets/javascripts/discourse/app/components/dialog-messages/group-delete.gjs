import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const GroupDelete = <template>
  {{#if @model.user_count}}
    <p>
      {{icon "users"}}
      {{i18n "admin.groups.delete_details" count=@model.user_count}}
    </p>
  {{/if}}
  {{#if @model.message_count}}
    <p>
      {{icon "envelope"}}
      {{i18n
        "admin.groups.delete_with_messages_confirm"
        count=@model.message_count
      }}
    </p>
  {{/if}}

  <p>
    {{icon "triangle-exclamation"}}
    {{i18n "admin.groups.delete_warning"}}
  </p>
</template>;

export default GroupDelete;
