import formatUsername from "discourse/helpers/format-username";
import { and } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const User = <template>
  {{dAvatar
    @result
    imageSize="small"
    template=@result.avatar_template
    username=@result.username
  }}
  <div class="user-titles">
    {{#if (and @displayNameWithUser @result.name)}}
      <span class="name">{{@result.name}}</span>
    {{/if}}
    <span class="username">
      {{formatUsername @result.username}}
    </span>
    {{#each @result.custom_data as |row|}}
      <span class="custom-field">{{row.name}}: {{row.value}}</span>
    {{/each}}
  </div>
</template>;

export default User;
