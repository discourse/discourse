const fs = require("fs");
const path = require("path");
// const glob = require("glob");

// Source and destination directories
const sourceDir = path.resolve(__dirname, "../select-kit/addon/components");
const destinationDir = path.resolve(__dirname, "./app/components");

// Ensure destination directory exists
if (!fs.existsSync(destinationDir)) {
  fs.mkdirSync(destinationDir, { recursive: true });
}

// Perform glob to find all files in the source directory
fs.glob(`${sourceDir}/*`, (err, files) => {
  if (err) {
    console.error("Error during glob operation:", err);
    process.exit(1);
  }

  files.forEach((file) => {
    const fileName = path.basename(file);
    const destinationFileName = `${fileName.split(".")[0]}.js`;
    const destinationPath = path.join(destinationDir, destinationFileName);
    const moduleName = `select-kit/components/${fileName.split(".")[0]}`;

    // Create an empty file in the destination directory
    fs.writeFileSync(
      destinationPath,
      `export { default } from "${moduleName}";\n`,
      "utf8"
    );
    console.log(`Created: ${destinationPath}`);
  });
});
