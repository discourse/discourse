import { SVG_NAMESPACE } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

const TIMEOUT = 2500;
const TRANSITION_BUFFER = 250;

export default function postActionFeedback({
  postId,
  actionClass,
  messageKey,
  actionCallback,
  errorCallback,
}) {
  if (recentlyCopied(postId, actionClass)) {
    return;
  }

  const maybePromise = actionCallback();

  if (maybePromise && maybePromise.then) {
    maybePromise
      .then(() => {
        showAlert(postId, actionClass, messageKey);
      })
      .catch(() => {
        if (errorCallback) {
          errorCallback();
        }
      });
  } else {
    showAlert(postId, actionClass, messageKey);
  }
}

export function recentlyCopied(postId, actionClass) {
  return document.querySelector(
    `article[data-post-id='${postId}'] .${actionClass} .${actionClass}-checkmark`
  );
}

export function showAlert(postId, actionClass, messageKey, opts = {}) {
  const postSelector = `article[data-post-id='${postId}']`;
  const actionBtn =
    opts.actionBtn || document.querySelector(`${postSelector} .${actionClass}`);

  actionBtn?.classList.add("post-action-feedback-button");

  createAlert(i18n(messageKey), postId, actionBtn);
  createCheckmark(actionBtn, actionClass, postId);
  styleBtn(actionBtn);
}

function createAlert(message, postId, actionBtn) {
  if (!actionBtn) {
    return;
  }

  let alertDiv = document.createElement("div");
  alertDiv.className = "post-action-feedback-alert -success";
  alertDiv.textContent = message;

  actionBtn.appendChild(alertDiv);

  setTimeout(() => removeElement(alertDiv), TIMEOUT);
}

function createCheckmark(btn, actionClass, postId) {
  const svgId = `svg_${actionClass}_${postId}`;
  const checkmark = makeCheckmarkSvg(postId, actionClass, svgId);
  btn.appendChild(checkmark.content);

  setTimeout(() => removeElement(document.getElementById(svgId)), TIMEOUT);
}

function styleBtn(btn) {
  btn.classList.add("--activated", "--transition");
  setTimeout(
    () => btn.classList.remove("--activated"),
    TIMEOUT - TRANSITION_BUFFER
  );
  setTimeout(() => btn.classList.remove("--transition"), TIMEOUT);
}

function makeCheckmarkSvg(postId, actionClass, svgId) {
  const svgElement = document.createElement("template");
  svgElement.innerHTML = `
      <svg class="${actionClass}-checkmark post-action-feedback-svg is-visible" id="${svgId}" xmlns="${SVG_NAMESPACE}" viewBox="0 0 52 52">
        <path class="checkmark__check" fill="none" d="M13 26 l10 10 20 -20"/>
      </svg>
    `;
  return svgElement;
}

function removeElement(element) {
  element?.parentNode?.removeChild(element);
}
