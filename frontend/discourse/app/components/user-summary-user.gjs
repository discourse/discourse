/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DUserInfo from "discourse/ui-kit/d-user-info";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

@tagName("")
export default class UserSummaryUser extends Component {
  <template>
    <li ...attributes>
      <DUserInfo @user={{@user}}>
        {{dIcon @icon}}
        <span class={{@countClass}}>{{dNumber @user.count}}</span>
      </DUserInfo>
    </li>
  </template>
}
