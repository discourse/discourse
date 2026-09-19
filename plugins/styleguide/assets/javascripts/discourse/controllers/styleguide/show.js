import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class StyleguideShow extends Controller {
  /**
   * The active group of a sectioned page. Sections that are not split simply ignore it.
   *
   * `null` because no section-independent default exists — the first group's id differs per
   * section — and `StyleguideGroups` already falls back to the first manifest entry when this
   * is absent or unrecognised.
   */
  @tracked group = null;
  queryParams = ["group"];

  @action
  dummyAction() {}
}
