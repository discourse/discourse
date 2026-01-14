import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class QuickSearch extends Service {
  @tracked loading = false;
  @tracked invalidTerm = false;
}
