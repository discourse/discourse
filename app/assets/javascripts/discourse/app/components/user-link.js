import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { attributeBindings, tagName } from "@ember-decorators/component";

@tagName("a")
@attributeBindings("href", "dataUserCard:data-user-card")
export default class UserLink extends Component {
  @alias("user.path") href;
  @alias("user.username") dataUserCard;
}
