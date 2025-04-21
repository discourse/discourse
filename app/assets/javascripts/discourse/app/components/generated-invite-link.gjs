import { i18n } from "discourse-i18n";

const GeneratedInviteLink = <template>
  <div>
    <p>{{i18n "user.invited.link_generated"}}</p>
    <p>
      <input
        value={{@link}}
        class="invite-link-input"
        type="text"
        autofocus="autofocus"
      />
    </p>
    {{#if @email}}
      <p>{{i18n "user.invited.valid_for" email=@email}}</p>
    {{/if}}
  </div>
</template>;

export default GeneratedInviteLink;
