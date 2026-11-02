import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

export default class ReviewableActionConfirmation extends Component {
  get hasUserPlaceholder() {
    return (
      this.args.model.confirm_user &&
      this.args.model.confirm_message_template?.includes("%{user}")
    );
  }

  @action
  keepReviewOpen(event) {
    event.stopPropagation();
  }

  <template>
    <p ...attributes>
      {{#if this.hasUserPlaceholder}}
        <DInterpolatedTranslation
          @translatedText={{@model.confirm_message_template}}
          as |Placeholder|
        >
          <Placeholder @name="user">
            {{~#let @model.confirm_user as |user|~}}
              <DUserLink
                class="reviewable-confirmation-user"
                rel="noopener"
                target="_blank"
                @user={{user}}
                {{on "click" this.keepReviewOpen}}
              >
                {{~dAvatar user imageSize="tiny"~}}@{{user.username~}}
              </DUserLink>
            {{~/let~}}
          </Placeholder>
        </DInterpolatedTranslation>
      {{else}}
        {{trustHTML @model.confirm_message}}
      {{/if}}
    </p>
  </template>
}
