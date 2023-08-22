import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class AppendTags extends Component {
  @tracked tags = [];
}
