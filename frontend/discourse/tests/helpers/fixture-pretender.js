export default function (helpers) {
  const { response } = helpers;
  const fixturesByUrl = {};

  // Load any fixtures automatically
  Object.keys(require.entries).forEach((entry) => {
    if (/^discourse\/tests\/fixtures/.test(entry)) {
      const fixture = require(entry, null, null, true);
      if (fixture && fixture.default) {
        const obj = fixture.default;
        Object.keys(obj).forEach((url) => {
          let fixtureUrl = url;
          if (fixtureUrl[0] !== "/") {
            fixtureUrl = "/" + fixtureUrl;
          }
          fixturesByUrl[url] = obj[url];
          this.get(fixtureUrl, () => response(obj[url]));
        });
      }
    }
  });

  return fixturesByUrl;
}
