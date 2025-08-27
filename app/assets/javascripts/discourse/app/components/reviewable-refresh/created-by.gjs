import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";

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
      <UserLink @user={{@user}}>{{avatar @user imageSize="small"}}</UserLink>
      <ReviewableCreatedByName @user={{@user}} />
    {{else}}
      {{icon "trash-can" class="deleted-user-avatar"}}
    {{/if}}
  </div>
</template>
