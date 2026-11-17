import DUserInfo from "discourse/ui-kit/d-user-info";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

const UserSummaryUser = <template>
  <li ...attributes>
    <DUserInfo @user={{@user}}>
      {{dIcon @icon}}
      <span class={{@countClass}}>{{dNumber @user.count}}</span>
    </DUserInfo>
  </li>
</template>;

export default UserSummaryUser;
