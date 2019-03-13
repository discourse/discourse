import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  basePath() {
    return "/admin/";
  },

  afterFindAll(results) {
    let map = {};
    results.forEach(theme => {
      map[theme.id] = theme;
    });
    results.forEach(theme => {
      let mapped = theme.get("child_themes") || [];
      mapped = mapped.map(t => map[t.id]);
      theme.set("childThemes", mapped);

      let mappedParents = theme.get("parent_themes") || [];
      mappedParents = mappedParents.map(t => map[t.id]);
      theme.set("parentThemes", mappedParents);
    });
    return results;
  },

  jsonMode: true
});
