import { computed } from "@ember/object";
import { getAbsoluteURL } from "discourse/lib/get-url";
import RestModel from "discourse/models/rest";

export default class PublishedPage extends RestModel {
  @computed("slug")
  get url() {
    return getAbsoluteURL(`/pub/${this.slug}`);
  }
}
