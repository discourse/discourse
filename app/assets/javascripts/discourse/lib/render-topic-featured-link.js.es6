import { h } from "virtual-dom";

const _decorators = [];

export function addFeaturedLinkMetaDecorator(decorator) {
  _decorators.push(decorator);
}

export function extractLinkMeta(topic) {
  const href = topic.get("featured_link");
  const target = Discourse.User.currentProp("external_links_in_new_tab")
    ? "_blank"
    : "";

  if (!href) {
    return;
  }

  const meta = {
    target: target,
    href,
    domain: topic.get("featured_link_root_domain"),
    rel: "nofollow"
  };

  if (_decorators.length) {
    _decorators.forEach(cb => cb(meta));
  }

  return meta;
}

export default function renderTopicFeaturedLink(topic) {
  const meta = extractLinkMeta(topic);
  if (meta) {
    return `<a class="topic-featured-link" rel="${meta.rel}" target="${
      meta.target
    }" href="${meta.href}">${meta.domain}</a>`;
  } else {
    return "";
  }
}

export function topicFeaturedLinkNode(topic) {
  const meta = extractLinkMeta(topic);
  if (meta) {
    return h(
      "a.topic-featured-link",
      {
        attributes: { href: meta.href, rel: meta.rel, target: meta.target }
      },
      meta.domain
    );
  }
}
