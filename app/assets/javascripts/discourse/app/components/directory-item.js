import Component from "@ember/component";
import {
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";

@tagName("div")
@classNames("directory-table__row")
@classNameBindings("me")
export default class DirectoryItem extends Component {
  @propertyEqual("item.user.id", "currentUser.id") me;
  columns = null;
}
