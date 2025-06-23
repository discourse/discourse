import { decorateGithubOneboxBody } from "discourse/instance-initializers/onebox-decorators";
import { samePrefix } from "discourse/lib/get-url";
import { decorateHashtags } from "discourse/lib/hashtag-decorator";
import highlightSyntax from "discourse/lib/highlight-syntax";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import lightbox from "../lib/lightbox";

export default {
  name: "chat-decorators",

  initializeWithPluginApi(api, container) {
    const siteSettings = container.lookup("service:site-settings");
    const site = container.lookup("service:site");

    api.decorateChatMessage((element) => decorateGithubOneboxBody(element), {
      id: "onebox-github-body",
    });

    api.decorateChatMessage(
      (element) => {
        element
          .querySelectorAll(".onebox.githubblob li.selected")
          .forEach((line) => {
            const scrollingElement = this._getScrollParent(line, "onebox");

            // most likely a very small file which doesn’t need scrolling
            if (!scrollingElement) {
              return;
            }

            const scrollBarWidth =
              scrollingElement.offsetHeight - scrollingElement.clientHeight;

            scrollingElement.scroll({
              top:
                line.offsetTop +
                scrollBarWidth -
                scrollingElement.offsetHeight / 2 +
                line.offsetHeight / 2,
            });
          });
      },
      {
        id: "onebox-github-scrolling",
      }
    );

    api.decorateChatMessage(
      (element) =>
        highlightSyntax(
          element,
          siteSettings,
          container.lookup("service:session")
        ),
      { id: "highlightSyntax" }
    );

    api.decorateChatMessage(this.renderChatTranscriptDates, {
      id: "transcriptDates",
    });

    api.decorateChatMessage(this.forceLinksToOpenNewTab, {
      id: "linksNewTab",
    });
    api.decorateChatMessage(
      (element) =>
        lightbox(element.querySelectorAll("img:not(.emoji, .avatar)")),
      {
        id: "lightbox",
      }
    );
    api.decorateChatMessage((element) => decorateHashtags(element, site), {
      id: "hashtagIcons",
    });
  },

  _getScrollParent(node, maxParentSelector) {
    if (node === null || node.classList.contains(maxParentSelector)) {
      return null;
    }

    if (node.scrollHeight > node.clientHeight) {
      return node;
    } else {
      return this._getScrollParent(node.parentNode, maxParentSelector);
    }
  },

  renderChatTranscriptDates(element) {
    element.querySelectorAll(".chat-transcript").forEach((transcriptEl) => {
      const dateTimeRaw = transcriptEl.dataset["datetime"];
      const dateTimeLinkEl = transcriptEl.querySelector(
        ".chat-transcript-datetime a"
      );

      // we only show date for first message
      if (!dateTimeLinkEl) {
        return;
      }

      if (dateTimeLinkEl.innerText !== "") {
        // same as highlight, no need to do this for every single message every time
        // any message changes
        return;
      }

      dateTimeLinkEl.innerText = moment(dateTimeRaw).format(
        i18n("dates.long_no_year")
      );
    });
  },

  forceLinksToOpenNewTab(element) {
    const links = element.querySelectorAll(
      "a:not([target]), a[target]:not([target='_blank'])"
    );
    for (let linkIndex = 0; linkIndex < links.length; linkIndex++) {
      const link = links[linkIndex];
      if (!DiscourseURL.isInternal(link.href) || !samePrefix(link.href)) {
        link.setAttribute("target", "_blank");
      }
    }
  },

  initialize(container) {
    if (container.lookup("service:chat").userCanChat) {
      withPluginApi("0.8.42", (api) =>
        this.initializeWithPluginApi(api, container)
      );
    }
  },
};
