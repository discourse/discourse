import { or } from "discourse/truth-helpers";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const Group = <template>
  <div class="group-result {{if @result.flairUrl '--with-flair'}}">
    {{#if @result.flairUrl}}
      <DAvatarFlair
        @flairName={{@result.name}}
        @flairUrl={{@result.flairUrl}}
        @flairBgColor={{@result.flairBgColor}}
        @flairColor={{@result.flairColor}}
      />
    {{else}}
      {{dIcon "users"}}
    {{/if}}
    <div class="group-names {{if @result.fullName '--group-with-slug'}}">
      <span class="name">{{or @result.fullName @result.name}}</span>
      {{! show the name of the group if we also show the full name }}
      {{#if @result.fullName}}
        <div class="slug">{{@result.name}}</div>
      {{/if}}
    </div>
  </div>
</template>;

export default Group;
