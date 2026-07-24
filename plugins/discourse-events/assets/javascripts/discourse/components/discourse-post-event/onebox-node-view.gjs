import Component from "@glimmer/component";
import { TOPIC_URL_REGEXP } from "discourse/lib/url";
import DiscoursePostEventOneboxPreview from "./onebox-preview";

// Returns the topic id for a topic-level / first-post onebox link, or null for
// anything else (including a link to a specific reply, post number > 1) — the
// event lives on the first post, so only that link should render the card.
//
// Only relative or same-origin URLs are considered: an absolute link to another
// Discourse site (e.g. https://meta.discourse.org/t/foo/123) must keep its
// external onebox rather than resolve to an unrelated local topic with id 123.
export function topicIdFromUrl(url) {
  if (!url) {
    return null;
  }

  let path;
  try {
    const parsed = new URL(url, window.location.origin);
    if (parsed.origin !== window.location.origin) {
      return null;
    }
    path = parsed.pathname;
  } catch {
    return null;
  }

  const match = path.match(TOPIC_URL_REGEXP);
  if (!match) {
    return null;
  }
  if (match[3] && parseInt(match[3], 10) !== 1) {
    return null;
  }
  return parseInt(match[2], 10);
}

// NodeView for the rich text editor's `onebox` node. For internal-topic oneboxes
// (gated by shouldRender in the rich-editor extension) it renders the read-only
// event card, falling back to the original onebox HTML for non-event topics.
// Only the visual rendering is overridden — the node's attrs and markdown
// serialization are untouched, so saving/copy-paste are unaffected.
export default class DiscoursePostEventOneboxNodeView extends Component {
  constructor() {
    super(...arguments);
    this.args.onSetup?.(this);
  }

  get topicId() {
    return topicIdFromUrl(this.args.node.attrs.url);
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  <template>
    <DiscoursePostEventOneboxPreview
      @topicId={{this.topicId}}
      @fallbackHtml={{@node.attrs.html}}
    />
  </template>
}
