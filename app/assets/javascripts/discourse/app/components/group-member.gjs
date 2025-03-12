import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";

@classNames("item")
export default class GroupMember extends Component {
  @action
  remove(event) {
    event?.preventDefault();
    this.removeAction(this.member);
  }
}

<a href={{this.member.adminPath}}>
  {{avatar this.member imageSize="small"}}
</a>
<span>{{this.member.username}}</span>
{{#unless this.automatic}}
  <a href {{on "click" this.remove}} class="remove">
    {{d-icon "xmark"}}
  </a>
{{/unless}}