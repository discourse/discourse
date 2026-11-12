import { AUTO_GROUPS } from "discourse/lib/constants";

// TODO (martin) Remove all this indirection when
// granular_anonymous_and_logged_in_groups_permissions is Permanent
const EVERYONE_ID = AUTO_GROUPS.everyone.id.toString();
const LOGGED_IN_USERS_ID = AUTO_GROUPS.logged_in_users.id.toString();

function normalizeIds(ids) {
  return ids.map((id) => id.toString());
}

export function mapEveryoneToLoggedInUsersIds(ids, granularPermissionsEnabled) {
  ids = normalizeIds(ids);

  if (!granularPermissionsEnabled || !ids.includes(EVERYONE_ID)) {
    return ids;
  }

  return [
    ...new Set(ids.map((id) => (id === EVERYONE_ID ? LOGGED_IN_USERS_ID : id))),
  ];
}

export function mapLoggedInUsersToEveryoneForStorage(
  ids,
  granularPermissionsEnabled,
  storedValue,
  tokenSeparator
) {
  if (!granularPermissionsEnabled) {
    return normalizeIds(ids);
  }

  const storedIds = normalizeIds(
    (storedValue || "").split(tokenSeparator).filter(Boolean)
  );

  if (
    !storedIds.includes(EVERYONE_ID) ||
    storedIds.includes(LOGGED_IN_USERS_ID)
  ) {
    return normalizeIds(ids);
  }

  return [
    ...new Set(
      normalizeIds(ids).map((id) =>
        id === LOGGED_IN_USERS_ID ? EVERYONE_ID : id
      )
    ),
  ];
}
