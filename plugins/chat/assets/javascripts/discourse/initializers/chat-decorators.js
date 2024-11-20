import $ from "jquery";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { decorateGithubOneboxBody } from "discourse/instance-initializers/onebox-decorators";
import { decorateHashtags } from "discourse/lib/hashtag-decorator";
import highlightSyntax from "discourse/lib/highlight-syntax";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import { samePrefix } from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default {
  name: "chat-decorators",

  initializeWithPluginApi(api, container) {
    const siteSettings = container.lookup("service:site-settings");
    const lightboxService = container.lookup("service:lightbox");
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

    if (siteSettings.enable_experimental_lightbox) {
      api.decorateChatMessage(
        (element) => {
          lightboxService.setupLightboxes({
            container: element,
            selector: "img:not(.emoji, .avatar, .site-icon)",
          });
        },
        {
          id: "experimental-chat-lightbox",
        }
      );
    } else {
      api.decorateChatMessage(
        (element) =>
          this.lightbox(element.querySelectorAll("img:not(.emoji, .avatar)")),
        {
          id: "lightbox",
        }
      );
    }
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

      if (this.currentUserTimezone) {
        dateTimeLinkEl.innerText = moment
          .tz(dateTimeRaw, this.currentUserTimezone)
          .format(i18n("dates.long_no_year"));
      } else {
        dateTimeLinkEl.innerText = moment(dateTimeRaw).format(
          i18n("dates.long_no_year")
        );
      }
    });
  },

  forceLinksToOpenNewTab(element) {
    const links = element.querySelectorAll(
      ".chat-message-text a:not([target='_blank'])"
    );
    for (let linkIndex = 0; linkIndex < links.length; linkIndex++) {
      const link = links[linkIndex];
      if (!DiscourseURL.isInternal(link.href) || !samePrefix(link.href)) {
        link.setAttribute("target", "_blank");
      }
    }
  },

  lightbox(images) {
    loadScript("/javascripts/jquery.magnific-popup.min.js").then(function () {
      $(images).magnificPopup({
        type: "image",
        closeOnContentClick: false,
        mainClass: "mfp-zoom-in",
        tClose: i18n("lightbox.close"),
        tLoading: spinnerHTML,
        image: {
          verticalFit: true,
        },
        gallery: {
          enabled: true,
        },
        callbacks: {
          elementParse: (item) => {
            item.src = item.el[0].dataset.largeSrc || item.el[0].src;
          },
        },
      });
    });
  },

  initialize(container) {
    if (container.lookup("service:chat").userCanChat) {
      withPluginApi("0.8.42", (api) =>
        this.initializeWithPluginApi(api, container)
      );
    }
  },
};
