import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { userPath } from "discourse/lib/url";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const User = <template>
  <a href={{userPath @user.username}} data-user-card={{@user.username}}>
    <span class="user">
      {{dAvatar @user imageSize="medium"}}
      <span class="username">
        {{userPrioritizedName @user}}
      </span>
    </span>
  </a>
</template>;

export default User;
