import SearchMenuResultComponent from "discourse/components/search-menu/results/type/result";
import { inject as service } from "@ember/service";

export default class TopicResult extends SearchMenuResultComponent {
  @service siteSettings;
}
