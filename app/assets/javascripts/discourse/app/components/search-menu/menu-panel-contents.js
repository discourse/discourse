import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class MenuPanelContents extends Component {
  @service search;

  get advancedSearchButtonHref() {
    return this.args.fullSearchUrl({ expanded: true });
  }
}
