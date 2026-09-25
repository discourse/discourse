export const customSearchTypes = [];

export function registerFullPageSearchType(
  translationKey,
  searchTypeId,
  searchFunc,
  options = {}
) {
  const searchType = {
    translationKey,
    searchTypeId,
    searchFunc,
    after: options.after,
  };
  const existing = customSearchTypes.findIndex(
    (type) => type.searchTypeId === searchTypeId
  );

  if (existing === -1) {
    customSearchTypes.push(searchType);
  } else {
    customSearchTypes[existing] = searchType;
  }
}
