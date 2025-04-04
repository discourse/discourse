const fs = require("fs");
const path = require("path");
// const glob = require("glob");

// Source and destination directories
const sourceDir = path.resolve(__dirname, "../admin/addon/helpers");
const destinationDir = path.resolve(__dirname, "./app/helpers");

// Ensure destination directory exists
if (!fs.existsSync(destinationDir)) {
  fs.mkdirSync(destinationDir, { recursive: true });
}

// Perform glob to find all files in the source directory
fs.glob(`${sourceDir}/**/*.*`, (err, files) => {
  if (err) {
    // eslint-disable-next-line no-console
    console.error("Error during glob operation:", err);
    process.exit(1);
  }

  files.forEach((file) => {
    const fileName = file.replace(`${sourceDir}/`, "");

    const destinationFileName = `${fileName.split(".")[0]}.js`;
    const destinationPath = path.join(destinationDir, destinationFileName);
    const moduleName = `admin/helpers/${fileName.split(".")[0]}`;

    // Create an empty file in the destination directory
    fs.mkdirSync(path.dirname(destinationPath), { recursive: true });
    fs.writeFileSync(
      destinationPath,
      `export { default } from "${moduleName}";\n`,
      "utf8"
    );
    // eslint-disable-next-line no-console
    console.log(`Created: ${destinationPath}`);
  });
});
