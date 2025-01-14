import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse/lib/helpers";

let usernameDecorators = [];
export function addUsernameSelectorDecorator(decorator) {
  usernameDecorators.push(decorator);
}

export function resetUsernameDecorators() {
  usernameDecorators = [];
}

export function decorateUsername(username) {
  const decorations = [];

  usernameDecorators.forEach((decorator) => {
    decorations.push(decorator(username));
  });

  return decorations.length ? htmlSafe(decorations.join("")) : "";
}

registerRawHelper("decorate-username-selector", decorateUsernameSelector);

export default function decorateUsernameSelector(username) {
  return decorateUsername(username);
}
