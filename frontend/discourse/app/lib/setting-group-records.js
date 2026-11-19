/**
 * Turns a group setting's choices into group records for the new group picker. Each record is
 * the site's group under the name the setting shows it by, with its id as a number.
 *
 * @param {{ id: string, name: string }[]} choices the setting's offered groups
 * @param {object[]} groups the site's groups
 * @returns {object[]}
 */
export function settingGroupRecords(choices, groups) {
  const groupsById = new Map((groups || []).map((group) => [group.id, group]));

  return choices.map(({ id, name }) => ({
    ...groupsById.get(Number(id)),
    id: Number(id),
    name,
  }));
}
