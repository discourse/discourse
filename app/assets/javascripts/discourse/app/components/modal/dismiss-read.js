import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class DismissRead extends Component {
  @tracked dismissTopics = false;
}
