import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const User = <template>
  <a
    data-user-card={{@ctx.user.username}}
    href="{{@ctx.baseuri}}/u/{{@ctx.user.username}}/activity"
  >
    {{dAvatar @ctx.user imageSize="tiny"}}
    {{@ctx.user.username}}
  </a>
</template>;

export default User;
