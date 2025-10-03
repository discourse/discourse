import UserInfo from "discourse/components/user-info";
import { i18n } from "discourse-i18n";

function cakedayDate(val, { isBirthday }) {
  const date = moment(val);

  if (isBirthday) {
    return date.format(i18n("dates.full_no_year_no_time"));
  } else {
    return date.format(i18n("dates.full_with_year_no_time"));
  }
}

const UserInfoList = <template>
  <ul class="user-info-list">
    {{#each @users as |user|}}
      <li class="user-info-item">
        <UserInfo @user={{user}}>
          <div>{{cakedayDate user.cakedate isBirthday=@isBirthday}}</div>
        </UserInfo>
      </li>
    {{else}}
      <div class="user-info-empty-message"><p>{{yield}}</p></div>
    {{/each}}
  </ul>
</template>;

export default UserInfoList;
