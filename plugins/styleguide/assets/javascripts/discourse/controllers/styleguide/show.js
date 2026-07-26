import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class StyleguideShow extends Controller {
  /**
   * The active group of a sectioned page.
   *
   * The default must stay `null`. Ember serializes a non-default sticky query-param value into
   * generated hrefs, and the styleguide's own nav links are bare `<LinkTo>`s with no `@query` —
   * so a non-null default would leak `?group=…` into every link and break the smoke test's
   * `href` assertions. Sections that are not split simply ignore it.
   */
  @tracked group = null;
  queryParams = ["group"];

  @action
  dummyAction() {}
}
