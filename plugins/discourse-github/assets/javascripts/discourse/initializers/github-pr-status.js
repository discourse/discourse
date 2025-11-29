import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

const GITHUB_PR_REGEX =
  /github\.com\/(?<owner>[^/]+)\/(?<repo>[^/]+)\/pull\/(?<number>\d+)/;

async function fetchPrStatus(owner, repo, number) {
  const response = await fetch(
    `/discourse-github/${owner}/${repo}/pulls/${number}/status.json`
  );
  if (!response.ok) {
    return null;
  }
  const data = await response.json();
  return data.state;
}

function applyStatus(onebox, status) {
  [...onebox.classList].forEach((cls) => {
    if (cls.startsWith("--gh-status-")) {
      onebox.classList.remove(cls);
    }
  });
  if (status) {
    onebox.classList.add(`--gh-status-${status}`);
    const iconContainer = onebox.querySelector(".github-icon-container");
    if (iconContainer) {
      iconContainer.title = i18n(`github.pr_status.${status}`);
    }
  }
}

async function processOnebox(onebox) {
  if (onebox.dataset.ghPrStatus) {
    return;
  }

  const match = onebox.dataset.oneboxSrc?.match(GITHUB_PR_REGEX);
  if (!match) {
    return;
  }

  const { owner, repo, number } = match.groups;
  onebox.dataset.ghPrStatus = "pending";
  const status = await fetchPrStatus(owner, repo, number);
  if (status) {
    onebox.dataset.ghPrStatus = status;
    applyStatus(onebox, status);
  }
}

function decorateElement(element) {
  element.querySelectorAll(".onebox.githubpullrequest").forEach(processOnebox);
}

export default {
  name: "github-pr-status",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.github_pr_status_enabled) {
      return;
    }

    const currentUser = container.lookup("service:current-user");
    if (!currentUser) {
      return;
    }

    withPluginApi((api) => {
      api.decorateCookedElement(decorateElement, {
        id: "github-pr-status",
      });

      api.decorateChatMessage?.(decorateElement, {
        id: "github-pr-status",
      });
    });
  },
};
