import avatar from "discourse/helpers/avatar";

const User = <template>
  {{#if @ctx.user}}
    <a
      href="{{@ctx.baseuri}}/u/{{@ctx.user.username}}/activity"
      data-user-card={{@ctx.user.username}}
    >
      {{avatar @ctx.user imageSize="tiny"}}
      {{@ctx.user.username}}
    </a>
  {{else}}
    {{@ctx.id}}
  {{/if}}
</template>;

export default User;
