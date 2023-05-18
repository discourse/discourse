import Component from "@glimmer/component";

export default class Results extends Component {
  get content() {
    this.siteSettings.use_pg_headlines_for_excerpt &&
    result.topic_title_headline
      ? new RawHtml({
          html: `<span>${emojiUnescape(result.topic_title_headline)}</span>`,
        })
      : new Highlighted(topic.fancyTitle, term);
  }
}
