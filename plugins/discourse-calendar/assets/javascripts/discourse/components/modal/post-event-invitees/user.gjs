import avatar from "discourse/helpers/avatar";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { userPath } from "discourse/lib/url";

const User = <template>
  <a href={{userPath @user.username}} data-user-card={{@user.username}}>
    <span class="user">
      {{avatar @user imageSize="medium"}}
      <span class="username">
        {{userPrioritizedName @user}}
      </span>
    </span>
  </a>
</template>;

export default User;
