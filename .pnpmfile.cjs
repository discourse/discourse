const fs = require("fs");
const { execSync, execFileSync } = require("child_process");

const discourseRoot = __dirname;

if (fs.existsSync(`${discourseRoot}/node_modules/.yarn-integrity`)) {
  console.log(
    "Detected yarn-managed node_modules. Performing one-time cleanup..."
  );

  // Delete entire contents of all node_modules directories
  // But keep the directories themselves, in case they are volume mounts (e.g. in devcontainer)
  execSync(
    `find ${discourseRoot}/node_modules ${discourseRoot}/app/assets/javascripts/*/node_modules -mindepth 1 -maxdepth 1 -exec rm -rf {} +`
  );

  console.log("cleanup done");
}

const pluginBase = `${discourseRoot}/plugins/`;
const cwd = process.cwd();
const pluginName =
  cwd.startsWith(pluginBase) && cwd.replace(pluginBase, "").split("/", 2)[0];

if (
  pluginName &&
  fs.existsSync(`${discourseRoot}/plugins/${pluginName}/package.json`) &&
  !process.argv.includes("--ignore-workspace")
) {
  console.log(
    "> pnpm was run inside a plugin directory. Re-executing with --ignore-workspace..."
  );

  const indexOfPnpm = process.argv.findIndex(
    (a) => a.includes("/pnpm") || a.endsWith("pnpm")
  );
  const newArgs = [...process.argv];
  newArgs.splice(indexOfPnpm + 1, 0, "--ignore-workspace");

  try {
    execFileSync(newArgs[0], newArgs.slice(1), {
      stdio: "inherit",
    });
  } catch (e) {
    if (e.status) {
      process.exit(e.status);
    }
    throw e;
  }

  process.exit(0);
}
