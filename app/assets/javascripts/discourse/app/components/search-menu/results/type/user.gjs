import { and } from "truth-helpers";
import avatar from "discourse/helpers/avatar";
import formatUsername from "discourse/helpers/format-username";

const User = <template>
  {{avatar
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
    {{#if @result.custom_data}}
      {{#each @result.custom_data as |row|}}
        <span class="custom-field">{{row.name}}: {{row.value}}</span>
      {{/each}}
    {{/if}}
  </div>
</template>;

export default User;
