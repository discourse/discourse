import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Post from "discourse/models/post";

export default class RawEmailComponent extends Component {
  @tracked rawEmail = this.args.model.rawEmail || "";
  @tracked textPart = "";
  @tracked htmlPart = "";
  @tracked tab = "raw";

  constructor() {
    super(...arguments);
    if (this.args.model.id) {
      this.loadRawEmail(this.args.model.id);
    }
  }

  @action
  async loadRawEmail(postId) {
    const result = await Post.loadRawEmail(postId);
    this.rawEmail = result.raw_email;
    this.textPart = result.text_part;
    this.htmlPart = result.html_part;
  }

  @action
  displayRaw() {
    this.tab = "raw";
  }

  @action
  displayTextPart() {
    this.tab = "text_part";
  }

  @action
  displayHtmlPart() {
    this.tab = "html_part";
  }
}
