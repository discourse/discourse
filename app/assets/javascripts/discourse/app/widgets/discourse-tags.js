import renderTags from "discourse/lib/render-tags";
import RawHtml from "discourse/widgets/raw-html";

// Right now it's RawHTML. Eventually it should emit nodes
export default class DiscourseTags extends RawHtml {
  constructor(attrs) {
    attrs.html = renderTags(attrs.topic, attrs);
    super(attrs);
  }
}
