import { withPluginApi } from "discourse/lib/plugin-api";

export function decorateGithubOneboxBody(element) {
  const containers = element.querySelectorAll(
    ".onebox.githubcommit .show-more-container, .onebox.githubpullrequest .show-more-container, .onebox.githubissue .show-more-container"
  );

  if (containers.length) {
    element.addEventListener("click", _handleClick, false);

    // cleanup function to remove the event listener while cleaning up the decorations
    return () => element.removeEventListener("click", _handleClick);
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

export default {
  initialize() {
    withPluginApi((api) => {
      api.decorateCookedElement(decorateGithubOneboxBody);
    });
  },
};
