import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { emojiUnescape } from "discourse/lib/text";
import { htmlSafe } from "@ember/template";

export default class Results extends Component {
  @service siteSettings;
  @service site;

  get unescapeHeadline() {
    return (
      this.siteSettings.use_pg_headlines_for_excerpt &&
      this.args.result.topic_title_headline
    );
  }

  get unescapedHeadline() {
    return htmlSafe(emojiUnescape(this.args.result.topic_title_headline));
  }
}
