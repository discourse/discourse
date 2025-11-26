import { getOwner } from "@ember/owner";
import { helperContext } from "discourse/lib/helpers";
import { buildImageMarkdown as buildImageMarkdownShared } from "discourse/lib/markdown-image-builder";
import { buildQuote } from "discourse/lib/quote";
import Composer from "discourse/models/composer";
import Draft from "discourse/models/draft";

function getExtensionFromUrl(url) {
  if (!url) {
    return null;
  }
  const match = url.match(/\.([a-zA-Z0-9]+)(?:\?|$)/);
  return match ? match[1] : null;
}

function buildImageMarkdown(slideElement, slideData) {
  const img = slideElement?.querySelector("img");

  if (!img) {
    return null;
  }

  let src;

  // Check for base62 SHA1 to use short upload:// URL format (same as to-markdown.js)
  if (slideData.base62SHA1) {
    const extension = getExtensionFromUrl(slideData.src);
    src = `upload://${slideData.base62SHA1}`;
    if (extension) {
      src += `.${extension}`;
    }
  } else {
    // Prefer data-orig-src (same as to-markdown.js)
    src = slideData.origSrc || slideData.src;
  }

  if (!src) {
    return null;
  }

  return buildImageMarkdownShared({
    src,
    alt: slideData.title,
    width: slideData.targetWidth,
    height: slideData.targetHeight,
    fallbackAlt: "image",
  });
}

export function canQuoteImage(slideElement, slideData) {
  if (!helperContext()?.currentUser) {
    return false;
  }
  return buildImageMarkdown(slideElement, slideData) !== null;
}

export default async function quoteImage(slideElement, slideData) {
  try {
    const ownerContext = helperContext();

    if (!slideElement || !ownerContext) {
      return false;
    }

    const owner = getOwner(ownerContext);

    if (!owner) {
      return false;
    }

    const markdown = buildImageMarkdown(slideElement, slideData);
    if (!markdown) {
      return false;
    }

    const composer = owner.lookup("service:composer");
    if (!composer) {
      return false;
    }

    const post = slideData.post;
    const quote = buildQuote(post, markdown);

    if (!quote) {
      return false;
    }

    if (composer.model?.viewOpen) {
      const appEvents = owner.lookup("service:app-events");
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
      draftKey: post.topic.draft_key,
      draftSequence: post.topic.draft_sequence,
    };

    if (post.post_number === 1) {
      composerOpts.topic = post.topic;
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
