import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";

@tagName("div")
@classNames("directory-table__row")
@classNameBindings("me")
@attributeBindings("role")
export default class DirectoryItem extends Component {
  role = "row";

  @propertyEqual("item.user.id", "currentUser.id") me;
  columns = null;
}
