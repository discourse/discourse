import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class CreateTopicButton extends Component {
  label = "topic.create";
  btnClass = "btn-default";
}
