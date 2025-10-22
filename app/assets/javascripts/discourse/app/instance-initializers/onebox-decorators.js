import { withPluginApi } from "discourse/lib/plugin-api";

let _showMoreClickPostsElements = [];

export function decorateGithubOneboxBody(element) {
  const containers = element.querySelectorAll(
    ".onebox.githubcommit .show-more-container, .onebox.githubpullrequest .show-more-container, .onebox.githubissue .show-more-container"
  );

  if (containers.length) {
    _showMoreClickPostsElements.push(element);
    element.addEventListener("click", _handleClick, false);
  }
}

function _handleClick(event) {
  if (!event.target.classList.contains("show-more")) {
    return;
  }

  event.preventDefault();

  const showMoreContainer = event.target.parentNode;
  const bodyContainer = showMoreContainer.parentNode;

  showMoreContainer.classList.add("hidden");
  bodyContainer.querySelector(".excerpt.hidden").classList.remove("hidden");

  return false;
}

function _cleanUp() {
  (_showMoreClickPostsElements || []).forEach((element) => {
    element.removeEventListener("click", _handleClick);
  });

  _showMoreClickPostsElements = [];
}

export default {
  initialize() {
    withPluginApi((api) => {
      api.decorateCookedElement((element) => {
        decorateGithubOneboxBody(element);
      });

      api.cleanupStream(_cleanUp);
    });
  },
};
