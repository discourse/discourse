import avatar from "discourse/helpers/avatar";
import { userPath } from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";

const User = <template>
  <a href={{userPath @user.username}} data-user-card={{@user.username}}>
    <span class="user">
      {{avatar @user imageSize="medium"}}
      <span class="username">
        {{formatUsername @user.username}}
      </span>
    </span>
  </a>
</template>;

export default User;
