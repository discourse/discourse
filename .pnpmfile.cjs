const fs = require("fs");
const { execSync } = require("child_process");

if (fs.existsSync("node_modules/.yarn-integrity")) {
  console.log(
    "Detected yarn-managed node_modules. Performing one-time cleanup..."
  );

  // Delete entire contents of all node_modules directories
  // But keep the directories themselves, in case they are volume mounts (e.g. in devcontainer)
  execSync(
    "find ./node_modules ./app/assets/javascripts/*/node_modules -mindepth 1 -maxdepth 1 -exec rm -rf {} +"
  );

  console.log("cleanup done");
}
