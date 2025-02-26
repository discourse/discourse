import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class PostNoticeCustom extends Component {
  @tracked createdByAnchorElement;

  registerCreatedByLink = modifier((element) => {
    this.createdByAnchorElement = element?.querySelector(".custom_created_by");
  });

  get createdByName() {
    return escapeExpression(
      prioritizeNameInUx(this.args.post.notice_created_by_user.name)
        ? this.args.post.notice_created_by_user.name
        : this.args.post.notice_created_by_user.username
    );
  }

  <template>
    {{icon "user-shield"}}
    <div class="post-notice-message test" {{this.registerCreatedByLink}}>
      {{htmlSafe @notice.cooked}}
      {{htmlSafe
        (i18n
          "post.notice.custom_created_by"
          userLinkHTML="<span class='custom_created_by'></span>"
        )
      }}
      {{! #in-element is used as an strategy to render the HTML content in the string from a real component
          instead defining it from a string }}
      {{#if this.createdByAnchorElement}}
        {{#in-element this.createdByAnchorElement}}
          <UserLink
            title={{this.createdByName}}
            @username={{@post.notice_created_by_user.username}}
            @ariaHidden={{false}}
          >
            {{this.createdByName}}
          </UserLink>
        {{/in-element}}
      {{/if}}
    </div>
  </template>
}
