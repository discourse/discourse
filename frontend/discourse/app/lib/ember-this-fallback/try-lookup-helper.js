import Helper from "@ember/component/helper";
import { getOwner } from "@ember/owner";

export default class TryLookupHelper extends Helper {
  compute([name]) {
    return getOwner(this).factoryFor(`helper:${name}`)?.class;
  }
}
