#! /usr/bin/env node

const fs = require("fs").promises;
const path = require("path");
const { globSync } = require("fs");

/**
 * Codemod to fix deprecated-resolver-normalization warnings by automatically
 * renaming routes, controllers and templates based on console deprecation messages
 */

class DeprecationFixer {
  constructor() {
    this.foundDeprecations = new Set();
    this.renamedFiles = [];
    this.errors = [];
    this.dryRun = true; // Default to dry-run mode
    this.discourseAppPath = path.join(
      __dirname,
      "..",
      "app",
      "assets",
      "javascripts",
      "discourse",
      "app"
    );

    // Collect all rewrites to perform in a single pass
    this.importRewrites = new Map(); // Map<filePath, Array<{oldImport, newImport}>>
    this.resolverRewrites = new Map(); // Map<filePath, Array<{pattern, replacement, description}>>
    this.stubsToCreate = new Set(); // Set<{stubPath, type, basePath}>
    this.oldResolverNames = new Set();
  }

  async run() {
    // Check for --apply flag to actually perform renames
    const args = process.argv.slice(2);
    this.dryRun = !args.includes("--apply");

    if (this.dryRun) {
      // eslint-disable-next-line no-console
      console.log(
        "🔍 Starting deprecation detection (DRY RUN - no files will be changed)"
      );
      // eslint-disable-next-line no-console
      console.log("   Use --apply flag to actually rename files");
    } else {
      // eslint-disable-next-line no-console
      console.log("🔍 Starting deprecation detection (APPLYING CHANGES)");
    }

    // Check if puppeteer is available
    let puppeteer;
    let chromeLauncher;
    try {
      puppeteer = require("puppeteer-core");
      chromeLauncher = require("chrome-launcher");
    } catch {
      // eslint-disable-next-line no-console
      console.error("❌ Puppeteer-core or chrome-launcher not found.");
      process.exit(1);
    }

    let browser;

    // Find Chrome executable
    const chromePath = chromeLauncher.Launcher.getInstallations()[0];
    if (!chromePath) {
      throw new Error("Chrome not found");
    }

    // Launch Puppeteer with Chrome executable path
    browser = await puppeteer.launch({
      executablePath: chromePath,
      headless: false, // Show browser for debugging
      devtools: false,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });

    const page = await browser.newPage();

    // Set up error handling for page
    page.on("pageerror", (error) => {
      // eslint-disable-next-line no-console
      console.log(`   ⚠️  Page error: ${error.message}`);
    });

    // Capture console messages
    const deprecations = [];
    page.on("console", (msg) => {
      const text = msg.text();
      if (
        text.includes("deprecated-resolver-normalization") &&
        text.includes("is no longer permitted")
      ) {
        deprecations.push(text);
        // eslint-disable-next-line no-console
        console.log("📍 Found deprecation:", text);
      }
    });

    // Navigate to Discourse development server
    // eslint-disable-next-line no-console
    console.log("🌐 Loading Discourse at localhost:4200...");
    await page.goto("http://localhost:4200/session/david/become", {
      waitUntil: "networkidle2",
      timeout: 30000,
    });

    // Wait a bit for all modules to load and deprecations to appear
    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Trigger more deprecations by systematically looking up all routes/controllers/templates
    // eslint-disable-next-line no-console
    console.log(
      "🔍 Triggering additional deprecations by looking up all registered routes..."
    );

    try {
      /* eslint-disable */
      // Look up all templates
      await page.evaluate(() => {
        Object.keys(
          Discourse.lookup("service:router")._router._routerMicrolib.recognizer
            .names
        ).forEach((r) => {
          try {
            Discourse.lookup(`template:${r}`);
          } catch {
            // Ignore lookup errors, we just want the deprecation messages
          }
        });
      });

      // Look up all controllers
      await page.evaluate(() => {
        Object.keys(
          Discourse.lookup("service:router")._router._routerMicrolib.recognizer
            .names
        ).forEach((r) => {
          try {
            Discourse.lookup(`controller:${r}`);
          } catch {
            // Ignore lookup errors, we just want the deprecation messages
          }
        });
      });

      // Look up all routes
      await page.evaluate(() => {
        Object.keys(
          Discourse.lookup("service:router")._router._routerMicrolib.recognizer
            .names
        ).forEach((r) => {
          try {
            Discourse.lookup(`route:${r}`);
          } catch {
            // Ignore lookup errors, we just want the deprecation messages
          }
        });
      });
      /* eslint-enable */

      // Wait a moment for any additional deprecations to be logged
      await new Promise((resolve) => setTimeout(resolve, 2000));
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(
        `   ⚠️  Could not trigger additional lookups: ${error.message}`
      );
    }

    await browser.close();

    // eslint-disable-next-line no-console
    console.log(
      `\n📊 Found ${deprecations.length} unique deprecation messages`
    );

    if (deprecations.length === 0) {
      // eslint-disable-next-line no-console
      console.log(
        "✅ No deprecations found! Either they're all fixed or the server isn't running."
      );
      // eslint-disable-next-line no-console
      console.log(
        "   Make sure Discourse is running at localhost:4200 before running this script."
      );
      return;
    }

    // Process the deprecations
    await this.processDeprecations(deprecations);

    for (const { stubPath, type, basePath } of this.stubsToCreate) {
      await this.createStubFile(type, stubPath, basePath);
    }

    // Apply all collected rewrites in a single pass
    await this.applyAllRewrites();

    // Report results
    this.reportResults();

    fs.writeFile("old-names.txt", [...this.oldResolverNames].join("\n") + "\n");
  }

  async processDeprecations(deprecations) {
    // eslint-disable-next-line no-console
    console.log("\n🔧 Processing deprecations...");

    // Remove duplicates
    const uniqueDeprecations = [...new Set(deprecations)];

    // eslint-disable-next-line no-console
    console.log(`   Processing ${uniqueDeprecations.length} unique messages`);

    for (const deprecation of uniqueDeprecations) {
      const parsed = this.parseDeprecationMessage(deprecation);
      if (parsed) {
        await this.handleFileRename(parsed);
      }
    }
  }

  parseDeprecationMessage(message) {
    // Pattern: "Looking up 'template:some-name' is no longer permitted. Rename to 'template:correct-name' instead"
    const match = message.match(
      /Looking up '([^']+)' is no longer permitted\. Rename to '([^']+)' instead/
    );
    if (!match) {
      return null;
    }

    const [, oldName, newName] = match;
    const [oldType, oldPath] = oldName.split(":", 2);
    const [newType, newPath] = newName.split(":", 2);

    if (oldType !== newType) {
      // eslint-disable-next-line no-console
      console.log(`   ⚠️  Type mismatch: ${oldType} vs ${newType}, skipping`);
      return null;
    }

    if (!["template", "controller", "route"].includes(oldType)) {
      // eslint-disable-next-line no-console
      console.log(`   ⚠️  Unknown type: ${oldType}, skipping`);
      return null;
    }

    return {
      type: oldType,
      oldPath,
      newPath,
    };
  }

  async handleFileRename({ type, oldPath, newPath }) {
    let skipRelated = false;
    // Convert resolver names to file paths
    let oldFilePath = this.resolverNameToFilePath(type, oldPath);
    const newFilePath = this.resolverNameToFilePath(type, newPath);

    if (!oldFilePath || !newFilePath) {
      this.errors.push(`Could not convert paths: ${oldPath} -> ${newPath}`);
      return;
    }

    // Find the primary file across all possible locations
    const adminBasePath = `${__dirname}/../app/assets/javascripts/admin/addon`;
    const searchPaths = [];

    if (!newPath.startsWith("admin")) {
      // If it's admin, then don't even look in the main app path
      searchPaths.push(this.discourseAppPath);
    }

    searchPaths.push(adminBasePath);

    searchPaths.push(
      ...(await globSync(
        `${__dirname}/../plugins/*/assets/javascripts/discourse`,
        {
          nodir: false,
        }
      ))
    );

    searchPaths.push(
      ...(await globSync(
        `${__dirname}/../plugins/*/admin/assets/javascripts/{admin,discourse}`,
        {
          nodir: false,
        }
      ))
    );

    let basePath;

    for (const searchPath of searchPaths) {
      const fullPath = path.join(searchPath, oldFilePath);
      const fileExists = await fs
        .access(fullPath)
        .then(() => true)
        .catch(() => false);

      if (fileExists) {
        basePath = searchPath;
        break;
      }
    }

    if (!basePath && oldPath.startsWith("admin-") && type === "template") {
      // Special case: admin templates might be named without the admin- prefix in the filesystem
      oldFilePath = this.resolverNameToFilePath(
        type,
        oldPath.replace(/^admin-/, "")
      );
      const fullPath = path.join(adminBasePath, oldFilePath);
      const fileExists = await fs
        .access(fullPath)
        .then(() => true)
        .catch(() => false);

      if (fileExists) {
        basePath = adminBasePath;
        skipRelated = true; // Skip related files for admin templates
      }
    }

    if (!basePath && oldPath.startsWith("admin-") && type === "template") {
      // Insane case: as above, but with underscores instead of dashes
      oldFilePath = this.resolverNameToFilePath(
        type,
        oldPath.replace(/^admin-/, "").replaceAll("-", "_")
      );
      const fullPath = path.join(adminBasePath, oldFilePath);
      const fileExists = await fs
        .access(fullPath)
        .then(() => true)
        .catch(() => false);

      if (fileExists) {
        basePath = adminBasePath;
        skipRelated = true; // Skip related files for admin templates
      }
    }

    if (!basePath) {
      return;
    }

    // Rename the primary file
    await this.renameFile(oldFilePath, newFilePath, basePath);

    // Update imports after rename
    await this.updateImportsAfterRename(oldFilePath, newFilePath, basePath);

    // Create stub file if we're moving from simple name to nested structure
    // e.g., group-index -> group/index means we need a group.js stub
    if (
      newPath.includes("/") &&
      newPath.endsWith("index") &&
      !oldPath.includes("/")
    ) {
      const stubPath = newPath.replace("/index", "");
      this.stubsToCreate.add({ stubPath, type, basePath });
    }

    if (!skipRelated) {
      const allTypes = ["controller", "route", "template"];
      const relatedTypes = allTypes.filter(
        (relatedType) => relatedType !== type
      );

      for (const relatedType of relatedTypes) {
        const relatedOldFilePath = this.resolverNameToFilePath(
          relatedType,
          oldPath
        );
        const relatedNewFilePath = this.resolverNameToFilePath(
          relatedType,
          newPath
        );

        if (relatedOldFilePath && relatedNewFilePath) {
          const relatedFullOldPath = path.join(basePath, relatedOldFilePath);
          const relatedFileExists = await fs
            .access(relatedFullOldPath)
            .then(() => true)
            .catch(() => false);

          if (relatedFileExists) {
            await this.renameFile(
              relatedOldFilePath,
              relatedNewFilePath,
              basePath,
              true
            );

            // Update imports for related files too
            await this.updateImportsAfterRename(
              relatedOldFilePath,
              relatedNewFilePath,
              basePath
            );

            // Create stub file for related files too if moving to nested structure
            if (
              newPath.includes("/") &&
              newPath.endsWith("index") &&
              !oldPath.includes("/")
            ) {
              const stubPath = newPath.replace("/index", "");
              this.stubsToCreate.add({ stubPath, type: relatedType, basePath });
            }
          }
        }
      }
    }
  }

  async renameFile(oldFilePath, newFilePath, basePath, isRelated = false) {
    const fullOldPath = path.join(basePath, oldFilePath);
    const fullNewPath = path.join(basePath, newFilePath);

    try {
      // Check if old file exists
      await fs.access(fullOldPath);

      if (this.dryRun) {
        // Dry run: just log what would happen
        const prefix = isRelated
          ? "   📎 Would rename related file:"
          : "   ✅ Would rename:";
        // eslint-disable-next-line no-console
        console.log(`${prefix} ${oldFilePath} -> ${newFilePath}`);
        this.renamedFiles.push({ oldPath: oldFilePath, newPath: newFilePath });
        return;
      }

      // Check if new file already exists
      try {
        await fs.access(fullNewPath);
        if (isRelated) {
          // eslint-disable-next-line no-console
          console.log(
            `   ℹ️  Related target file already exists: ${newFilePath}`
          );
        } else {
          // eslint-disable-next-line no-console
          console.log(`   ⚠️  Target file already exists: ${newFilePath}`);
        }
        return;
      } catch {
        // New file doesn't exist, good to proceed
      }

      // Create directory for new file if needed
      const newDir = path.dirname(fullNewPath);
      await fs.mkdir(newDir, { recursive: true });

      // Rename the file
      await fs.rename(fullOldPath, fullNewPath);

      const prefix = isRelated
        ? "   📎 Related file renamed:"
        : "   ✅ Renamed:";
      // eslint-disable-next-line no-console
      console.log(`${prefix} ${oldFilePath} -> ${newFilePath}`);
      this.renamedFiles.push({ oldPath: oldFilePath, newPath: newFilePath });
    } catch (error) {
      if (error.code === "ENOENT") {
        if (!isRelated) {
          // Only log missing primary files, not missing related files
          const verb = this.dryRun ? "would rename" : "renamed";
          // eslint-disable-next-line no-console
          console.log(
            `   ℹ️  File not found (maybe already ${verb}): ${oldFilePath}`
          );
        }
      } else {
        this.errors.push(`Failed to rename ${oldFilePath}: ${error.message}`);
      }
    }
  }

  async updateImportsAfterRename(oldFilePath, newFilePath, basePath) {
    // eslint-disable-next-line no-console
    console.log(
      `   🔄 Collecting import updates for: ${oldFilePath} -> ${newFilePath}`
    );

    // Collect outgoing import updates (imports within the renamed file)
    await this.collectOutgoingImportUpdates(oldFilePath, newFilePath, basePath);

    // Collect incoming import updates (other files importing this file)
    await this.collectIncomingImportUpdates(oldFilePath, newFilePath, basePath);

    // Collect resolver reference updates (controllerFor, lookup calls, etc.)
    await this.collectResolverReferenceUpdates(oldFilePath, newFilePath);
  }

  filePathToResolverName(filePath) {
    // Convert file path to resolver name
    // e.g., controllers/user-activity-bookmarks.js -> user-activity-bookmarks
    // e.g., controllers/user-activity/bookmarks.js -> user-activity/bookmarks
    // Remove the type prefix (controllers/, routes/, templates/) and file extension
    const parts = filePath.split("/");
    const pathWithoutType = parts.slice(1).join("."); // Remove first part (controllers/routes/templates)
    return pathWithoutType.replace(/\.(js|gjs)$/, "");
  }

  filePathToModuleName(filePath, basePath) {
    // Convert file path to Discourse module name
    // e.g., controllers/group-index.js -> discourse/controllers/group-index

    let prefix;
    if (basePath.includes("javascripts/discourse/app")) {
      prefix = "discourse/";
    } else if (basePath.includes("javascripts/admin/addon")) {
      prefix = "admin/";
    } else if (basePath.includes("plugins/")) {
      const pluginNameMatch = basePath.match(/plugins\/([^\/]+)\//);
      prefix = `discourse/plugins/${pluginNameMatch[1]}/discourse/`;
    }

    return prefix + filePath.replace(/\.(js|gjs)$/, "");
  }

  getRelativeImportPath(fromFile, toFile) {
    const fromDir = path.dirname(fromFile);
    const relativePath = path.relative(fromDir, toFile);

    // Normalize to use forward slashes and add ./ prefix if needed
    const normalized = relativePath
      .replace(/\\/g, "/")
      .replace(/\.(js|gjs)$/, "");

    if (!normalized.startsWith("../") && !normalized.startsWith("./")) {
      return "./" + normalized;
    }

    return normalized;
  }

  async findJSFiles() {
    const jsFiles = [];

    // Helper function to scan a directory for JS files
    const scanDirectory = async (baseDir, pattern = "**/*.{js,gjs}") => {
      await fs.access(baseDir);
      const matches = await globSync(pattern, {
        cwd: baseDir,
        nodir: true,
      });

      return matches.map((match) => ({
        fullPath: path.resolve(baseDir, match),
        relativePath: match.replace(/\\/g, "/"),
      }));
    };

    // Scan main discourse app directory
    const discourseFiles = await scanDirectory(this.discourseAppPath);
    jsFiles.push(...discourseFiles);

    // Scan admin addon directory
    const adminFiles = await scanDirectory(
      `${__dirname}/../app/assets/javascripts/admin/addon`
    );
    jsFiles.push(...adminFiles);

    // Scan discourse tests directory
    const testFiles = await scanDirectory(
      `${__dirname}/../app/assets/javascripts/discourse/tests`
    );
    jsFiles.push(...testFiles);

    // Find and scan plugin directories
    const pluginDirs = await globSync(
      `${__dirname}/../plugins/*/assets/javascripts/discourse`,
      {
        nodir: false,
      }
    );

    pluginDirs.push(
      ...(await globSync(`${__dirname}/../plugins/*/test/javascripts`, {
        nodir: false,
      }))
    );

    pluginDirs.push(
      ...(await globSync(
        `${__dirname}/../plugins/*/admin/assets/javascripts/{admin,discourse}`,
        {
          nodir: false,
        }
      ))
    );

    for (const entry of pluginDirs) {
      const pluginFiles = await scanDirectory(entry);
      jsFiles.push(...pluginFiles);
    }

    return jsFiles;
  }

  async createStubFile(type, resolverPath, basePath, isRelated = false) {
    const stubFilePath = this.resolverNameToFilePath(type, resolverPath);
    if (!stubFilePath) {
      return;
    }

    const fullStubPath = path.join(basePath, stubFilePath);

    try {
      // Check if stub file already exists
      await fs.access(fullStubPath);
      return; // Stub already exists, skip
    } catch {
      // File doesn't exist, create it
    }

    if (this.dryRun) {
      const prefix = isRelated
        ? "   📋 Would create related stub:"
        : "   📋 Would create stub:";
      // eslint-disable-next-line no-console
      console.log(`${prefix} ${stubFilePath}`);
      return;
    }

    // Generate stub content based on file type
    let stubContent;
    switch (type) {
      case "controller":
        stubContent = `import Controller from "@ember/controller";\n\nexport default class extends Controller {\n}\n`;
        break;
      case "route":
        stubContent = `import Route from "@ember/routing/route";\n\nexport default class extends Route {\n}\n`;
        break;
      case "template":
        stubContent = `<template>\n  {{outlet}}\n</template>\n`;
        break;
      default:
        return;
    }

    try {
      // Create directory if needed
      const stubDir = path.dirname(fullStubPath);
      await fs.mkdir(stubDir, { recursive: true });

      // Write the stub file
      await fs.writeFile(fullStubPath, stubContent, "utf8");

      const prefix = isRelated
        ? "   📋 Created related stub:"
        : "   📋 Created stub:";
      // eslint-disable-next-line no-console
      console.log(`${prefix} ${stubFilePath}`);
    } catch (error) {
      this.errors.push(
        `Failed to create stub ${stubFilePath}: ${error.message}`
      );
    }
  }

  resolverNameToFilePath(type, resolverPath) {
    // Convert resolver paths like 'admin-dashboard' to file paths like 'controllers/admin-dashboard.js'
    let filePath;

    switch (type) {
      case "controller":
        filePath = `controllers/${resolverPath}.js`;
        break;
      case "route":
        filePath = `routes/${resolverPath}.js`;
        break;
      case "template":
        filePath = `templates/${resolverPath}.gjs`;
        break;
      default:
        return null;
    }

    return filePath;
  }

  reportResults() {
    // eslint-disable-next-line no-console
    console.log("\n📋 Summary:");

    const verb = this.dryRun ? "would be renamed" : "renamed";
    // eslint-disable-next-line no-console
    console.log(`✅ Files that ${verb}: ${this.renamedFiles.length}`);

    if (this.renamedFiles.length > 0) {
      // eslint-disable-next-line no-console
      console.log(`\nFiles that ${verb}:`);
      for (const { oldPath, newPath } of this.renamedFiles) {
        // eslint-disable-next-line no-console
        console.log(`   ${oldPath} -> ${newPath}`);
      }
    }

    if (this.errors.length > 0) {
      // eslint-disable-next-line no-console
      console.log(`\n❌ Errors: ${this.errors.length}`);
      for (const error of this.errors) {
        // eslint-disable-next-line no-console
        console.log(`   ${error}`);
      }
    }

    if (this.renamedFiles.length > 0) {
      if (this.dryRun) {
        // eslint-disable-next-line no-console
        console.log("\n� To actually apply these changes, run:");
        // eslint-disable-next-line no-console
        console.log("   ./script/fix-routes.js --apply");
      } else {
        // eslint-disable-next-line no-console
        console.log("\n�🎉 Codemod completed! Remember to:");
        // eslint-disable-next-line no-console
        console.log("   1. Check git diff to review the changes");
        // eslint-disable-next-line no-console
        console.log("   2. Run tests to ensure nothing broke");
        // eslint-disable-next-line no-console
        console.log("   3. Update any references in other files if needed");
      }
    } else if (this.errors.length === 0) {
      // eslint-disable-next-line no-console
      console.log("\n✨ No files needed to be renamed!");
    }
  }

  async applyAllRewrites() {
    // Initialize pending updates if not already done
    this.pendingIncomingUpdates = this.pendingIncomingUpdates || [];
    this.pendingResolverUpdates = this.pendingResolverUpdates || [];

    if (
      this.importRewrites.size === 0 &&
      this.pendingIncomingUpdates.length === 0 &&
      this.pendingResolverUpdates.length === 0
    ) {
      return;
    }

    // eslint-disable-next-line no-console
    console.log(
      `\n🔄 Applying all collected rewrites in a single file pass...`
    );

    // Get all JS files for the incoming and resolver updates
    const allJSFiles = await this.findJSFiles();

    let totalChanges = 0;
    let filesModified = 0;

    for (const file of allJSFiles) {
      try {
        const { fullPath, relativePath } = file;
        let content = await fs.readFile(fullPath, "utf-8");
        const originalContent = content;
        let fileChanges = 0;

        // Apply import rewrites for this specific file
        const importUpdates = this.importRewrites.get(relativePath) || [];
        for (const { oldImport, newImport, description } of importUpdates) {
          const regex = new RegExp(
            `from\\s+(['"])${oldImport.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1`,
            "g"
          );
          const beforeCount = (content.match(regex) || []).length;
          if (beforeCount > 0) {
            content = content.replace(regex, `from $1${newImport}$1`);
            fileChanges += beforeCount;

            if (this.dryRun) {
              // eslint-disable-next-line no-console
              console.log(
                `   📦 Would update import in ${relativePath}: ${description}`
              );
            } else {
              // eslint-disable-next-line no-console
              console.log(
                `   📦 Updated import in ${relativePath}: ${description}`
              );
            }
          }
        }

        // Apply all pending incoming import updates to this file
        for (const { pattern, replacement, description } of this
          .pendingIncomingUpdates) {
          const regex = new RegExp(pattern, "g");
          const beforeCount = (content.match(regex) || []).length;
          if (beforeCount > 0) {
            content = content.replace(regex, replacement);
            fileChanges += beforeCount;

            if (this.dryRun) {
              // eslint-disable-next-line no-console
              console.log(
                `   📦 Would update import in ${relativePath}: ${description}`
              );
            } else {
              // eslint-disable-next-line no-console
              console.log(
                `   📦 Updated import in ${relativePath}: ${description}`
              );
            }
          }
        }

        // Apply all pending resolver updates to this file
        for (const { pattern, replacement, description } of this
          .pendingResolverUpdates) {
          const regex = new RegExp(pattern, "g");
          const beforeCount = (content.match(regex) || []).length;
          if (beforeCount > 0) {
            content = content.replace(regex, replacement);
            fileChanges += beforeCount;

            if (this.dryRun) {
              // eslint-disable-next-line no-console
              console.log(
                `   🔧 Would update resolver in ${relativePath}: ${description}`
              );
            } else {
              // eslint-disable-next-line no-console
              console.log(
                `   🔧 Updated resolver in ${relativePath}: ${description}`
              );
            }
          }
        }

        // Write the file if changes were made and not in dry-run mode
        if (content !== originalContent) {
          if (!this.dryRun) {
            await fs.writeFile(fullPath, content, "utf-8");
          }
          filesModified++;
          totalChanges += fileChanges;
        }
      } catch {
        // Skip files we can't read/write
      }
    }

    // eslint-disable-next-line no-console
    console.log(
      `✅ ${this.dryRun ? "Would apply" : "Applied"} ${totalChanges} changes across ${filesModified} files`
    );
  }

  async collectOutgoingImportUpdates(oldFilePath, newFilePath, basePath) {
    try {
      const filePathToRead = this.dryRun ? oldFilePath : newFilePath;
      const fullFilePath = path.join(basePath, filePathToRead);
      const content = await fs.readFile(fullFilePath, "utf-8");

      // Calculate the depth change for relative imports
      const oldDepth = oldFilePath.split("/").length - 1;
      const newDepth = newFilePath.split("/").length - 1;
      const depthChange = newDepth - oldDepth;

      if (depthChange === 0) {
        return; // No depth change, no updates needed
      }

      const importMatches = content.matchAll(/from\s+(['"])(\.\.?\/[^'"]*)\1/g);
      const updates = [];

      for (const match of importMatches) {
        const [, , importPath] = match;
        let newImportPath = importPath;

        if (depthChange > 0) {
          // Going deeper, add more ../
          newImportPath =
            "../".repeat(depthChange) + importPath.replace(/^\.\//, "");
        } else {
          // Going shallower, remove ../
          const prefixToRemove = "../".repeat(-depthChange);
          if (importPath.startsWith(prefixToRemove)) {
            newImportPath = importPath.substring(prefixToRemove.length);
            if (
              !newImportPath.startsWith("./") &&
              !newImportPath.startsWith("../")
            ) {
              newImportPath = "./" + newImportPath;
            }
          }
        }

        if (newImportPath !== importPath) {
          updates.push({
            oldImport: importPath,
            newImport: newImportPath,
            description: `${importPath} -> ${newImportPath}`,
          });
        }
      }

      if (updates.length > 0) {
        const targetFile = this.dryRun ? oldFilePath : newFilePath;
        this.importRewrites.set(
          targetFile,
          (this.importRewrites.get(targetFile) || []).concat(updates)
        );
      }
    } catch {
      // File might not exist or be readable, skip
    }
  }

  async collectIncomingImportUpdates(oldFilePath, newFilePath, basePath) {
    const oldModuleName = this.filePathToModuleName(oldFilePath, basePath);
    const newModuleName = this.filePathToModuleName(newFilePath, basePath);

    // Add the import update pattern for later application during the single file pass
    const relativeUpdate = {
      pattern: `from\\s+(['"])${oldModuleName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1`,
      replacement: `from $1${newModuleName}$1`,
      description: `${oldModuleName} -> ${newModuleName}`,
    };

    // We'll apply this to all files during the single pass
    this.pendingIncomingUpdates = this.pendingIncomingUpdates || [];
    this.pendingIncomingUpdates.push(relativeUpdate);
  }

  async collectResolverReferenceUpdates(oldFilePath, newFilePath) {
    const oldResolverName = this.filePathToResolverName(oldFilePath);
    const newResolverName = this.filePathToResolverName(newFilePath);

    // Store patterns for later application during the single file pass
    // Convert dash-separated names to camelCase for controllerFor patterns
    const camelCaseOldName = oldResolverName.replace(
      /-([a-z])/g,
      (match, letter) => letter.toUpperCase()
    );
    const camelCaseNewName = newResolverName.replace(
      /-([a-z])/g,
      (match, letter) => letter.toUpperCase()
    );

    const type = oldFilePath.split("/")[0]; // controllers, routes, templates

    const patterns = [];

    if (type === "routes") {
      patterns.push(
        {
          pattern: `controllerFor\\s*\\(\\s*(['"])${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `controllerFor($1${newResolverName}$1)`,
          description: `controllerFor: ${oldResolverName} -> ${newResolverName}`,
        },
        {
          pattern: `controllerFor\\s*\\(\\s*(['"])${camelCaseOldName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `controllerFor($1${camelCaseNewName}$1)`,
          description: `controllerFor (camelCase): ${camelCaseOldName} -> ${camelCaseNewName}`,
        },
        {
          pattern: `modelFor\\s*\\(\\s*(['"])${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `modelFor($1${newResolverName}$1)`,
          description: `modelFor: ${oldResolverName} -> ${newResolverName}`,
        },
        {
          pattern: `modelFor\\s*\\(\\s*(['"])${camelCaseOldName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `modelFor($1${camelCaseNewName}$1)`,
          description: `modelFor (camelCase): ${camelCaseOldName} -> ${camelCaseNewName}`,
        },
        {
          pattern: `lookup\\s*\\(\\s*(['"])route:${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `lookup($1route:${newResolverName}$1)`,
          description: `lookup route: ${oldResolverName} -> ${newResolverName}`,
        }
      );
    }

    if (type === "controllers") {
      patterns.push(
        {
          pattern: `lookup\\s*\\(\\s*(['"])controller:${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `lookup($1controller:${newResolverName}$1)`,
          description: `lookup controller: ${oldResolverName} -> ${newResolverName}`,
        },
        {
          pattern: `controllerName\\s*=\\s*(['"])${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1`,
          replacement: `controllerName = $1${newResolverName}$1`,
          description: `controllerName: ${oldResolverName} -> ${newResolverName}`,
        }
      );
    }

    if (type === "templates") {
      patterns.push(
        {
          pattern: `lookup\\s*\\(\\s*(['"])template:${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1\\s*\\)`,
          replacement: `lookup($1template:${newResolverName}$1)`,
          description: `lookup template: ${oldResolverName} -> ${newResolverName}`,
        },
        {
          pattern: `templateName\\s*=\\s*(['"])${oldResolverName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\1`,
          replacement: `templateName = $1${newResolverName}$1`,
          description: `templateName: ${oldResolverName} -> ${newResolverName}`,
        }
      );
    }

    // We'll apply these to all files during the single pass
    this.pendingResolverUpdates = this.pendingResolverUpdates || [];
    this.pendingResolverUpdates.push(...patterns);
    this.oldResolverNames.add(oldResolverName);
  }
}

// Run the codemod
if (require.main === module) {
  const fixer = new DeprecationFixer();
  fixer.run().catch((error) => {
    // eslint-disable-next-line no-console
    console.error(error);
    process.exit(1);
  });
}

module.exports = DeprecationFixer;
