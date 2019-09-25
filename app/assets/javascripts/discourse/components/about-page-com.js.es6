import computed from "ember-addons/ember-computed-decorators";
import { userPath } from "discourse/lib/url";
import { formatUsername, escapeExpression } from "discourse/lib/utilities";
import { normalize } from "discourse/components/user-info";
import { renderAvatar } from "discourse/helpers/user-avatar";

export default Ember.Component.extend({
  @computed("users")
  html(users) {
    return;
    let html = "";
    users.forEach(user => {
      let name = "";
      if (user.name && normalize(user.username) !== normalize(user.name)) {
        name = user.name;
      }
      html += `
        <div data-username="${user.username}" class="user-info small">
          <div class="user-image">
            <div class="user-image-inner">
              <a href="${userPath(user.username)}" data-user-card="${
        user.username
      }">
                ${renderAvatar(user, { imageSize: "large" })}
              </a>
            </div>
          </div>
          <div class="user-detail">
            <div class="name-line">
              <span class="username">
                <a href="${userPath(user.username)}" data-user-card="${
        user.username
      }">
                  ${formatUsername(user.username)}
                </a>
              </span>
              <span class="name">${escapeExpression(name)}</span>
            </div>
            <div class="title">${escapeExpression(user.title || "")}</div>
          </div>
        </div>
      `;
    });
    return html;
  }
});
