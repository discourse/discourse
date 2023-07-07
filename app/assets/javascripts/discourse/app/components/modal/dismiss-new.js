import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class DismissNew extends Component {
  dismissTopics = true;
  dismissPosts = true;
  untrack = false;

  @action
  dismissed() {
    this.args.model.dismissCallback({
      dismissTopics: this.dismissTopics,
      dismissPosts: this.dismissPosts,
      untrack: this.untrack,
    });

    this.args.closeModal();
  }
}
