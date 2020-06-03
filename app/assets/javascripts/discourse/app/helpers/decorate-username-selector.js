import { htmlSafe } from "@ember/template";
import { registerUnbound } from "discourse-common/lib/helpers";

let usernameDecorators = [];
export function addUsernameSelectorDecorator(decorator) {
  usernameDecorators.push(decorator);
}

export function resetUsernameDecorators() {
  usernameDecorators = [];
}

export default registerUnbound("decorate-username-selector", username => {
  const decorations = [];

  usernameDecorators.forEach(decorator => {
    decorations.push(decorator(username));
  });

  return decorations.length ? htmlSafe(decorations.join("")) : "";
});
