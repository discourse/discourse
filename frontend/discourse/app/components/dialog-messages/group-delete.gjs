import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const GroupDelete = <template>
  {{#if @model.user_count}}
    <p>
      {{dIcon "users"}}
      {{i18n "admin.groups.delete_details" count=@model.user_count}}
    </p>
  {{/if}}
  {{#if @model.message_count}}
    <p>
      {{dIcon "envelope"}}
      {{i18n
        "admin.groups.delete_with_messages_confirm"
        count=@model.message_count
      }}
    </p>
  {{/if}}

  <p>
    {{dIcon "triangle-exclamation"}}
    {{i18n "admin.groups.delete_warning"}}
  </p>
</template>;

export default GroupDelete;
