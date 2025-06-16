import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import escape from "discourse/lib/escape";
import highlightHTML from "discourse/lib/highlight-html";
import { iconHTML } from "discourse/lib/icon-library";
import { postUrl } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

// TODO (glimmer-post-stream): investigate whether all this complex logic can be replaced with a proper Glimmer component
export default function (element, context) {
  const { state } = context;

  const quotes = element.querySelectorAll("aside.quote");
  if (quotes.length === 0) {
    return;
  }

  state.originalQuoteContents = new Map();

  quotes.forEach((aside, index) => {
    if (aside.dataset.post) {
      const quoteId = `quote-id-${aside.dataset.topic}-${aside.dataset.post}-${index}`;

      const blockquote = aside.querySelector("blockquote");
      if (blockquote) {
        blockquote.id = quoteId;
      }

      _updateQuoteElements(aside, "chevron-down", context);
      const title = aside.querySelector(".title");

      if (!title) {
        return;
      }

      // If post/topic is not found then display username, skip controls
      if (aside.classList.contains("quote-post-not-found")) {
        if (aside.dataset.username) {
          title.innerHTML = escape(aside.dataset.username);
        } else {
          title.remove();
        }

        return;
      }

      // Unless it's a full quote, allow click to expand
      if (!aside.dataset.full && !title.dataset.hasQuoteControls) {
        title.addEventListener("click", (e) => {
          if (e.target.closest("a")) {
            return true;
          }

          _toggleQuote(aside, context);
        });

        title.dataset.hasQuoteControls = true;
      }
    }
  });
}

function _updateQuoteElements(aside, desc, context) {
  const { data } = context;

  const quoteTitle = i18n("post.follow_quote");
  const postNumber = aside.dataset.post;
  const topicNumber = aside.dataset.topic;

  // If we have a post reference
  let navLink = "";
  if (
    topicNumber &&
    postNumber &&
    topicNumber === data.post.topic_id?.toString() &&
    data.post.topic
  ) {
    const topicId = data.post.topic_id;
    const slug = data.post.topic.slug;

    const url = postUrl(slug, topicId, postNumber);
    const icon = iconHTML("arrow-up");

    navLink = `<a href='${url}' title='${quoteTitle}' class='btn-flat back'>${icon}</a>`;
  }

  // Only add the expand/contract control if it's not a full post
  const titleElement = aside.querySelector(".title");
  let expandContract = "";

  if (!aside.dataset.full) {
    const icon = iconHTML(desc, { title: "post.expand_collapse" });
    const quoteId = aside.querySelector("blockquote")?.id;

    if (quoteId) {
      const isExpanded = aside.dataset.expanded === "true";
      expandContract = `<button aria-controls="${quoteId}" aria-expanded="${isExpanded}" class="quote-toggle btn-flat">${icon}</button>`;

      if (titleElement) {
        titleElement.style.cursor = "pointer";
      }
    }
  }

  if (data.ignoredUsers?.length && titleElement) {
    const username = titleElement.innerText.trim().slice(0, -1);

    if (username.length > 0 && data.ignoredUsers.includes(username)) {
      aside.querySelectorAll("p").forEach((el) => el.remove());
      aside.classList.add("ignored-user");
    }
  }

  const quoteControls = aside.querySelector(".quote-controls");
  if (quoteControls) {
    quoteControls.innerHTML = expandContract + navLink;
  }
}

async function _toggleQuote(aside, context) {
  const {
    createDetachedElement,
    data,
    renderNestedPostCookedHtml,
    state,
    owner,
  } = context;

  if (state.expanding) {
    return;
  }

  state.expanding = true;
  const blockQuote = aside.querySelector("blockquote");

  if (!blockQuote) {
    return;
  }

  if (aside.dataset.expanded) {
    delete aside.dataset.expanded;
  } else {
    aside.dataset.expanded = true;
  }

  const quoteId = blockQuote.id;

  if (aside.dataset.expanded) {
    _updateQuoteElements(aside, "chevron-up", context);

    // Show expanded quote
    state.originalQuoteContents.set(quoteId, blockQuote.innerHTML);

    const originalText =
      blockQuote.textContent.trim() ||
      data.post.cooked.querySelector("blockquote").textContent.trim();

    blockQuote.innerHTML = spinnerHTML;

    const topicId = parseInt(aside.dataset.topic || data.post.topic_id, 10);
    const postId = parseInt(aside.dataset.post, 10);

    try {
      const post = data.post;
      const quotedPost = owner
        .lookup("service:store")
        .createRecord(
          "post",
          await ajax(`/posts/by_number/${topicId}/${postId}`)
        );

      if (quotedPost.topic_id === post?.topic_id) {
        quotedPost.topic = post.topic;
      }

      const quotedPosts = post.quoted || {};
      quotedPosts[quotedPost.id] = quotedPost;
      post.quoted = quotedPosts;

      const div = createDetachedElement("div");
      div.classList.add("expanded-quote");
      div.dataset.postId = quotedPost.id;

      // inception
      renderNestedPostCookedHtml(div, quotedPost, (element) =>
        // to highlight the quoted text inside the original post content
        highlightHTML(element, originalText, {
          matchCase: true,
        })
      );

      blockQuote.innerHTML = "";
      blockQuote.appendChild(div);
    } catch (e) {
      if (e.jqXHR && [403, 404].includes(e.jqXHR.status)) {
        const icon = iconHTML(e.jqXHR.status === 403 ? "lock" : "trash-can");
        blockQuote.innerHTML = `<div class='expanded-quote icon-only'>${icon}</div>`;
      } else {
        popupAjaxError(e);
      }
    }
  } else {
    // Hide expanded quote
    _updateQuoteElements(aside, "chevron-down", context);
    blockQuote.innerHTML = state.originalQuoteContents.get(blockQuote.id);
  }

  state.expanding = false;
}
