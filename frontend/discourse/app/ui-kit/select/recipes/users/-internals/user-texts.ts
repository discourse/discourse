import type {
  SelectCoreTextKey,
  SelectTexts,
} from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** The texts a user picker accepts: the engine's and the type words its chips speak. */
export type SelectUserTextKey = SelectCoreTextKey | "groupType" | "emailType";

/** The type words read after a group's or an address's name in a chip. */
export const USER_TEXTS: SelectTexts = Object.freeze({
  groupType: { translationKey: "select_user.group_type" },
  emailType: { translationKey: "select_user.email_type" },
});

/**
 * The picker's name, one whole string for each mix of what it offers, so translations never
 * join pieces.
 */
export function userPickerName({
  plural,
  groups,
  emails,
}: {
  /** Whether the field holds more than one. */
  plural: boolean;
  /** Whether groups are offered. */
  groups: boolean;
  /** Whether addresses are offered. */
  emails: boolean;
}): string {
  if (groups && emails) {
    return plural
      ? i18n("select_user.users_groups_or_emails")
      : i18n("select_user.user_group_or_email");
  }
  if (groups) {
    return plural
      ? i18n("select_user.users_or_groups")
      : i18n("select_user.user_or_group");
  }
  if (emails) {
    return plural
      ? i18n("select_user.users_or_emails")
      : i18n("select_user.user_or_email");
  }
  return plural ? i18n("select_user.users") : i18n("select_user.user");
}
