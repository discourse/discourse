import { computed } from "@ember/object";
import RestModel from "discourse/models/rest";
import { getAbsoluteURL } from "discourse-common/lib/get-url";

export default class PublishedPage extends RestModel {
  @computed("slug")
  get url() {
    return getAbsoluteURL(`/pub/${this.slug}`);
  }
}
