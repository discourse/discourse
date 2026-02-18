const { execSync } = require("node:child_process");

module.exports = {
  hooks: {
    beforePacking(pkg) {
      const discourseVersion = execSync(
        "ruby -r ./lib/version.rb -e 'puts Discourse::VERSION::STRING'",
        { encoding: "utf8" }
      ).match(/([0-9.]+)-/)[1];
      const commitHash = execSync("git rev-parse HEAD", {
        encoding: "utf8",
      }).trim();

      pkg.version = `${discourseVersion}-${commitHash}`;

      return pkg;
    },
  },
};
