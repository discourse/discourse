import { isValidLink } from "discourse/lib/click-track";
import { number } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

export default function (element, context) {
  const { post } = context;

  const linkCounts = post.link_counts;
  if (!linkCounts?.length) {
    return;
  }

  // find the best <a> element in each onebox and display link counts only
  // for that one (the best element is the most significant one to the
  // viewer)
  const bestElements = new Map();
  element.querySelectorAll("aside.onebox").forEach((onebox) => {
    // look in headings first
    for (let i = 1; i <= 6; ++i) {
      const hLinks = onebox.querySelectorAll(`h${i} a[href]`);
      if (hLinks.length > 0) {
        bestElements.set(onebox, hLinks[0]);
        return;
      }
    }

    // use the header otherwise
    const hLinks = onebox.querySelectorAll("header a[href]");
    if (hLinks.length > 0) {
      bestElements.set(onebox, hLinks[0]);
    }
  });

  linkCounts.forEach((lc) => {
    if (!lc.clicks || lc.clicks < 1) {
      return;
    }

    element.querySelectorAll("a[href]").forEach((link) => {
      const href = link.getAttribute("href");
      let valid = href === lc.url;

      // this might be an attachment
      if (lc.internal && /^\/uploads\//.test(lc.url)) {
        valid = href.includes(lc.url);
      }

      // match server-side behavior for internal links with query params
      if (lc.internal && /\?/.test(href)) {
        valid = href.split("?")[0] === lc.url;
      }

      // don't display badge counts on category badge & oneboxes (unless when explicitly stated)
      if (valid && isValidLink(link)) {
        const onebox = link.closest(".onebox");

        if (
          !onebox ||
          !bestElements.has(onebox) ||
          bestElements.get(onebox) === link
        ) {
          link.setAttribute("data-clicks", number(lc.clicks));

          const countText = i18n("post.link_clicked", {
            count: lc.clicks,
          });
          const ariaLabel = `${link.textContent.trim()} ${countText}`;
          link.setAttribute("aria-label", ariaLabel);
        }
      }
    });
  });
}
