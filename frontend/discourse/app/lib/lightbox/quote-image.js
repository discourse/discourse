import { getOwner } from "@ember/owner";
import { helperContext } from "discourse/lib/helpers";
import { buildImageMarkdown as buildImageMarkdownShared } from "discourse/lib/markdown-image-builder";
import { buildQuote } from "discourse/lib/quote";
import Composer from "discourse/models/composer";
import Draft from "discourse/models/draft";

function extractPostContext(element) {
  if (!element) {
    return null;
  }

  const article = element.closest("article[data-post-id]");
  if (!article) {
    return null;
  }

  const topicPost = article.closest(".topic-post");
  const postId = article.dataset.postId;
  const topicId = article.dataset.topicId;
  const postNumber = topicPost?.dataset.postNumber;

  if (!postId) {
    return null;
  }

  return {
    postId,
    topicId,
    postNumber,
  };
}

function parseDimension(value) {
  if (!value && value !== 0) {
    return null;
  }

  const parsed = parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function buildImageMarkdown(element) {
  const img = element?.querySelector("img");

  if (!img) {
    return null;
  }

  // Check for base62 SHA1 to use short upload:// URL format (same as to-markdown.js)
  const base62SHA1 = img.getAttribute("data-base62-sha1");
  let src;

  if (base62SHA1) {
    src = `upload://${base62SHA1}`;
  } else {
    // Prefer data-orig-src (same as to-markdown.js)
    src =
      img.getAttribute("data-orig-src")?.trim() ||
      element.getAttribute("href")?.trim() ||
      img.getAttribute("src")?.trim();
  }

  if (!src) {
    return null;
  }

  // Prefer data-target-width/height (same as to-markdown.js)
  const width =
    parseDimension(element.getAttribute("data-target-width")) ??
    parseDimension(img.getAttribute("width"));
  const height =
    parseDimension(element.getAttribute("data-target-height")) ??
    parseDimension(img.getAttribute("height"));

  const alt =
    img.getAttribute("alt") ||
    element.getAttribute("title") ||
    element.querySelector(".filename")?.textContent;

  return buildImageMarkdownShared({
    src,
    alt,
    width,
    height,
    fallbackAlt: "image",
  });
}

function extractQuoteDetails(element) {
  const postContext = extractPostContext(element);

  if (!postContext) {
    return null;
  }

  const markdown = buildImageMarkdown(element);

  if (!markdown) {
    return null;
  }

  return { postContext, markdown };
}

async function findPost(owner, store, postId) {
  const numericId = parseInt(postId, 10);
  const lookupId = Number.isFinite(numericId) ? numericId : postId;
  const topicController = owner.lookup("controller:topic");
  const postStream = topicController?.model?.postStream;

  let post = postStream?.findLoadedPost?.(lookupId);

  if (!post) {
    post = store.peekRecord("post", lookupId);
  }

  if (post) {
    return post;
  }

  try {
    return await store.find("post", lookupId);
  } catch {
    return null;
  }
}

function resolveTopic(owner, store, post, topicId) {
  const numericId = topicId ? parseInt(topicId, 10) : null;

  if (post.topic) {
    const postTopicId = parseInt(post.topic.id, 10);
    if (!numericId || postTopicId === numericId) {
      return post.topic;
    }
  }

  const topicController = owner.lookup("controller:topic");
  if (topicController?.model) {
    const controllerTopicId = parseInt(topicController.model.id, 10);
    if (!numericId || controllerTopicId === numericId) {
      return topicController.model;
    }
  }

  if (numericId) {
    return store.peekRecord("topic", numericId);
  }

  return null;
}

export function canQuoteImage(element) {
  return Boolean(extractQuoteDetails(element));
}

export default async function quoteImage(element) {
  try {
    const ownerContext = helperContext();

    if (!element || !ownerContext) {
      return false;
    }

    const owner = getOwner(ownerContext);

    if (!owner) {
      return false;
    }

    const details = extractQuoteDetails(element);

    if (!details) {
      return false;
    }

    const store = owner.lookup("service:store");
    const composer = owner.lookup("service:composer");
    const appEvents = owner.lookup("service:app-events");

    if (!store || !composer) {
      return false;
    }

    const post = await findPost(owner, store, details.postContext.postId);

    if (!post) {
      return false;
    }

    if (!post.post_number && details.postContext.postNumber) {
      const parsedPostNumber = parseInt(details.postContext.postNumber, 10);
      if (Number.isFinite(parsedPostNumber)) {
        post.post_number = parsedPostNumber;
      }
    }

    const topic = resolveTopic(owner, store, post, details.postContext.topicId);

    if (!topic?.draft_key) {
      return false;
    }

    if (!post.topic) {
      post.topic = topic;
    }

    const quote = buildQuote(post, details.markdown);

    if (!quote) {
      return false;
    }

    if (composer.model?.viewOpen) {
      appEvents?.trigger("composer:insert-block", quote);
      return true;
    }

    if (composer.model?.viewDraft) {
      const model = composer.model;
      model.reply = model.reply + "\n" + quote;
      composer.openIfDraft();
      return true;
    }

    const composerOpts = {
      action: Composer.REPLY,
      draftKey: topic.draft_key,
      draftSequence: topic.draft_sequence,
    };

    if (post.post_number === 1) {
      composerOpts.topic = topic;
    } else {
      composerOpts.post = post;
    }

    const draftData = await Draft.get(composerOpts.draftKey);

    if (draftData.draft) {
      const data = JSON.parse(draftData.draft);
      composerOpts.draftSequence = draftData.draft_sequence;
      composerOpts.reply = data.reply + "\n" + quote;
    } else {
      composerOpts.quote = quote;
    }

    await composer.open(composerOpts);
    return true;
  } catch {
    return false;
  }
}
