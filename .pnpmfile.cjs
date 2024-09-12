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

if (
  process.cwd().startsWith(`${discourseRoot}/plugins/`) &&
  !process.argv.includes("--ignore-workspace")
) {
  console.log(
    "> pnpm was run inside a plugin directory. Re-executing with --ignore-workspace..."
  );

  try {
    execFileSync(
      process.argv[0],
      [...process.argv.slice(1), "--ignore-workspace"],
      {
        stdio: "inherit",
      }
    );
  } catch (e) {
    if (e.status) {
      process.exit(e.status);
    }
    throw e;
  }

  process.exit(0);
}
