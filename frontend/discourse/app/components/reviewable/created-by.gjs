import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Displays the creator information for a reviewable item.
 * Shows the user's avatar and name if available, or a deleted user icon if the user no longer exists.
 *
 * @component ReviewableCreatedBy
 *
 * @example
 * ```gjs
 * <ReviewableCreatedBy @user={{this.reviewable.created_by}} />
 * ```
 *
 * @param {User} [user] - The user that created the reviewable item
 */
<template>
  <div class="created-by">
    {{#if @user}}
      <DUserLink @user={{@user}}>{{dAvatar @user imageSize="small"}}</DUserLink>
      <ReviewableCreatedByName @user={{@user}} />
    {{else}}
      <div class="deleted-user">
        {{dIcon "trash-can" class="deleted-user-avatar"}}
        <span class="deleted-user-name">{{i18n "review.deleted_user"}}</span>
      </div>
    {{/if}}
  </div>
</template>
