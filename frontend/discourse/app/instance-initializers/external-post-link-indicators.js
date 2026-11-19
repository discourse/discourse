import { iconElement } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

const SKIP_LINKS =
  ".onebox, .lightbox-wrapper, .lightbox, .mention, .mention-group, .hashtag-cooked, .attachment, .btn, .quote .title, .footnote-ref, .footnote-backref";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    if (!siteSettings.show_external_post_link_indicators) {
      return;
    }

    withPluginApi((api) => {
      api.decorateCookedElement(
        (element) => {
          const internalHosts = new Set([
            window.location.hostname.toLowerCase(),
            ...siteSettings.external_post_link_internal_hosts
              .split("|")
              .map((host) => host.trim().toLowerCase()),
          ]);

          for (const link of element.querySelectorAll("a[href]")) {
            if (
              !["http:", "https:"].includes(link.protocol) ||
              internalHosts.has(link.hostname.toLowerCase()) ||
              link.closest(SKIP_LINKS) ||
              link.classList.contains("post-external-link") ||
              !link.textContent.trim()
            ) {
              continue;
            }

            const icon = iconElement("up-right-from-square");
            icon.classList.add("post-external-link__icon");

            link.classList.add("post-external-link");
            if (!link.hasAttribute("aria-description")) {
              link.setAttribute(
                "aria-description",
                i18n("post.external_link_indicator")
              );
            }
            link.append(icon);
          }
        },
        { onlyStream: true }
      );
    });
  },
};
