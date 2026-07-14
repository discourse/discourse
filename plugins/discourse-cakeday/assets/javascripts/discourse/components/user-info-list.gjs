import DUserInfo from "discourse/ui-kit/d-user-info";
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
    {{#each @users.content as |user|}}
      <li class="user-info-item">
        <DUserInfo @user={{user}}>
          <div>{{cakedayDate user.cakedate isBirthday=@isBirthday}}</div>
        </DUserInfo>
      </li>
    {{else}}
      <div class="user-info-empty-message"><p>{{yield}}</p></div>
    {{/each}}
  </ul>
</template>;

export default UserInfoList;
