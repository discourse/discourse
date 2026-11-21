import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

export default <template>
  <td class="d-table__cell --detail">
    <span class="d-table__mobile-label">{{i18n
        "event_registration.library.created_by"
      }}</span>
    {{#if @form.created_by}}
      <DUserLink
        class="event-registration-form-creator"
        @user={{@form.created_by}}
      >
        {{dAvatar @form.created_by imageSize="tiny" hideTitle=true}}
        {{@form.created_by.username}}
      </DUserLink>
    {{else if @form.builtin}}
      {{i18n "event_registration.library.system_creator"}}
    {{else}}
      —
    {{/if}}
  </td>
</template>
