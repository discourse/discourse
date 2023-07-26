import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

export default class ChangeTags extends Component {
  @tracked tags = [];
}
