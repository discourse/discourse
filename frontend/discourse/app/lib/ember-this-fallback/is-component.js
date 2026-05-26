import Helper from "@ember/component/helper";
import { getOwner } from "@ember/owner";

export default class IsComponent extends Helper {
  compute([name]) {
    return Boolean(getOwner(this).factoryFor(`component:${name}`));
  }
}
