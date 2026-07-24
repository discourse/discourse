import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const User = <template>
  {{#if @ctx.user}}
    <a
      href="{{@ctx.baseuri}}/u/{{@ctx.user.username}}/activity"
      data-user-card={{@ctx.user.username}}
    >
      {{dAvatar @ctx.user imageSize="tiny"}}
      {{@ctx.user.username}}
    </a>
  {{else}}
    {{@ctx.id}}
  {{/if}}
</template>;

export default User;
