export default function(helpers) {
  const { response } = helpers;
  const fixturesByUrl = {};

  // Load any fixtures automatically
  Ember.keys(require._eak_seen).forEach(entry => {
    if (/^fixtures/.test(entry)) {
      const fixture = require(entry, null, null, true);
      if (fixture && fixture.default) {
        const obj = fixture.default;
        Ember.keys(obj).forEach(url => {
          fixturesByUrl[url] = obj[url];
          this.get(url, () => response(obj[url]));
        });
      }
    }
  });

  return fixturesByUrl;
};
