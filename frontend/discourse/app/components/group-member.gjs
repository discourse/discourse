/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@tagName("")
export default class GroupMember extends Component {
  @action
  remove(event) {
    event?.preventDefault();
    this.removeAction(this.member);
  }

  <template>
    <div class="item" ...attributes>
      <a href={{this.member.adminPath}}>
        {{dAvatar this.member imageSize="small"}}
      </a>
      <span>{{this.member.username}}</span>
      {{#unless this.automatic}}
        <a href {{on "click" this.remove}} class="remove">
          {{dIcon "xmark"}}
        </a>
      {{/unless}}
    </div>
  </template>
}
