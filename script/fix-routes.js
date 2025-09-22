#! /usr/bin/env node

const fs = require("fs").promises;
const path = require("path");

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
  }

  async run() {
    // Check for --apply flag to actually perform renames
    const args = process.argv.slice(2);
    this.dryRun = !args.includes('--apply');

    if (this.dryRun) {
      // eslint-disable-next-line no-console
      console.log("🔍 Starting deprecation detection (DRY RUN - no files will be changed)");
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
      console.error(
        "❌ Puppeteer-core or chrome-launcher not found."
      );
      process.exit(1);
    }

    let browser;
    try {
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
      await page.goto("http://localhost:4200", {
        waitUntil: "networkidle2",
        timeout: 30000,
      });

      // Wait a bit for all modules to load and deprecations to appear
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Trigger more deprecations by systematically looking up all routes/controllers/templates
      // eslint-disable-next-line no-console
      console.log("🔍 Triggering additional deprecations by looking up all registered routes...");
      
      try {
        /* eslint-disable */
        // Look up all templates
        await page.evaluate(() => {
          Object.keys(Discourse.lookup("service:router")._router._routerMicrolib.recognizer.names).forEach((r) => {
            try {
              Discourse.lookup(`template:${r}`);
            } catch {
              // Ignore lookup errors, we just want the deprecation messages
            }
          });
        });

        // Look up all controllers  
        await page.evaluate(() => {
          Object.keys(Discourse.lookup("service:router")._router._routerMicrolib.recognizer.names).forEach((r) => {
            try {
              Discourse.lookup(`controller:${r}`);
            } catch {
              // Ignore lookup errors, we just want the deprecation messages
            }
          });
        });

        // Look up all routes
        await page.evaluate(() => {
          Object.keys(Discourse.lookup("service:router")._router._routerMicrolib.recognizer.names).forEach((r) => {
            try {
              Discourse.lookup(`route:${r}`);
            } catch {
              // Ignore lookup errors, we just want the deprecation messages
            }
          });
        });
        /* eslint-enable */

        // Wait a moment for any additional deprecations to be logged
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        // eslint-disable-next-line no-console
        console.log(`   ⚠️  Could not trigger additional lookups: ${error.message}`);
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

      // Report results
      this.reportResults();
    } catch (error) {
      if (browser) {
        await browser.close();
      }

      if (error.message.includes("ERR_CONNECTION_REFUSED")) {
        // eslint-disable-next-line no-console
        console.error(
          "❌ Could not connect to localhost:4200. Make sure Discourse dev server is running."
        );
        // eslint-disable-next-line no-console
        console.error(
          "   Run: bin/ember-cli -u (or use the shortcuts/boot-dev task)"
        );
      } else {
        // eslint-disable-next-line no-console
        console.error("❌ Error:", error.message);
      }
      process.exit(1);
    }
  }

  async processDeprecations(deprecations) {
    // eslint-disable-next-line no-console
    console.log("\n🔧 Processing deprecations...");

    // Remove duplicates
    const uniqueDeprecations = [...new Set(deprecations)];

    // eslint-disable-next-line no-console
    console.log(`   Processing ${uniqueDeprecations.length} unique messages`);

    for (const deprecation of uniqueDeprecations) {
      try {
        const parsed = this.parseDeprecationMessage(deprecation);
        if (parsed) {
          await this.handleFileRename(parsed);
        }
      } catch (error) {
        this.errors.push(`Error processing "${deprecation}": ${error.message}`);
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
    // Convert resolver names to file paths
    const oldFilePath = this.resolverNameToFilePath(type, oldPath);
    const newFilePath = this.resolverNameToFilePath(type, newPath);

    if (!oldFilePath || !newFilePath) {
      this.errors.push(`Could not convert paths: ${oldPath} -> ${newPath}`);
      return;
    }

    // Check if the primary file exists before trying to rename it
    const fullOldPath = path.join(this.discourseAppPath, oldFilePath);
    const primaryFileExists = await fs.access(fullOldPath).then(() => true).catch(() => false);

    if (primaryFileExists) {
      // Rename the primary file
      await this.renameFile(oldFilePath, newFilePath);

      // Update imports after rename
      await this.updateImportsAfterRename(oldFilePath, newFilePath);

      // Create stub file if we're moving from simple name to nested structure
      // e.g., group-index -> group/index means we need a group.js stub
      if (newPath.includes('/') && newPath.endsWith('index') && !oldPath.includes('/')) {
        const stubPath = newPath.replace('/index', '');
        await this.createStubFile(type, stubPath);
      }
    }

    // Always try to rename related files regardless of the primary type
    const allTypes = ["controller", "route", "template"];
    const relatedTypes = allTypes.filter(relatedType => relatedType !== type);
    
    for (const relatedType of relatedTypes) {
      const relatedOldFilePath = this.resolverNameToFilePath(relatedType, oldPath);
      const relatedNewFilePath = this.resolverNameToFilePath(relatedType, newPath);
      
      if (relatedOldFilePath && relatedNewFilePath) {
        const relatedFullOldPath = path.join(this.discourseAppPath, relatedOldFilePath);
        const relatedFileExists = await fs.access(relatedFullOldPath).then(() => true).catch(() => false);
        
        if (relatedFileExists) {
          await this.renameFile(relatedOldFilePath, relatedNewFilePath, true);
          
          // Update imports for related files too
          await this.updateImportsAfterRename(relatedOldFilePath, relatedNewFilePath);
          
          // Create stub file for related files too if moving to nested structure
          if (newPath.includes('/') && newPath.endsWith('index') && !oldPath.includes('/')) {
            const stubPath = newPath.replace('/index', '');
            await this.createStubFile(relatedType, stubPath, true);
          }
        }
      }
    }
  }

  async renameFile(oldFilePath, newFilePath, isRelated = false) {
    const fullOldPath = path.join(this.discourseAppPath, oldFilePath);
    const fullNewPath = path.join(this.discourseAppPath, newFilePath);

    try {
      // Check if old file exists
      await fs.access(fullOldPath);

      if (this.dryRun) {
        // Dry run: just log what would happen
        const prefix = isRelated ? "   📎 Would rename related file:" : "   ✅ Would rename:";
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
          console.log(`   ℹ️  Related target file already exists: ${newFilePath}`);
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

      const prefix = isRelated ? "   📎 Related file renamed:" : "   ✅ Renamed:";
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

  async updateImportsAfterRename(oldFilePath, newFilePath) {
    try {
      // eslint-disable-next-line no-console
      console.log(`   🔄 ${this.dryRun ? 'Would update' : 'Updating'} imports for: ${oldFilePath} -> ${newFilePath}`);
      
      // In dry-run mode, read from the old path; otherwise read from new path
      const filePathToRead = this.dryRun ? oldFilePath : newFilePath;
      
      // Update imports in the renamed file (outgoing)
      await this.updateOutgoingImports(path.join(this.discourseAppPath, filePathToRead), oldFilePath, newFilePath);
      
      // Update imports in other files that reference this file (incoming)  
      await this.updateIncomingImports(oldFilePath, newFilePath);
      
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(`   ⚠️  Error updating imports for ${oldFilePath}: ${error.message}`);
    }
  }

  async findImportUpdates(oldFilePath, newFilePath) {
    const outgoing = [];
    const incoming = [];
    
    try {
      const fullNewPath = path.join(this.discourseAppPath, newFilePath);
      
      // Check outgoing imports in the file itself
      if (await fs.access(fullNewPath).then(() => true).catch(() => false)) {
        const content = await fs.readFile(fullNewPath, 'utf-8');
        const importMatches = content.match(/from\s+['"](\.\.?\/[^'"]*)['"]/g) || [];
        outgoing.push(...importMatches);
      }
      
      // Check incoming imports from other files
      const appFiles = await this.findJSFiles();
      for (const file of appFiles) {
        if (file === oldFilePath || file === newFilePath) {
          continue;
        }
        
        const fullPath = path.join(this.discourseAppPath, file);
        try {
          const content = await fs.readFile(fullPath, 'utf-8');
          const oldModuleName = this.filePathToModuleName(oldFilePath);
          
          // Check for imports of the old file
          const importRegex = new RegExp(`from\\s+['"](${oldModuleName}|\\.\\.?/[^'"]*${oldModuleName})['"]`, 'g');
          if (importRegex.test(content)) {
            incoming.push(file);
          }
        } catch {
          // Skip files we can't read
        }
      }
    } catch {
      // Return empty arrays on error
    }
    
    return { outgoing, incoming };
  }

  async updateOutgoingImports(fullFilePath, oldFilePath, newFilePath) {
    try {
      let content = await fs.readFile(fullFilePath, 'utf-8');
      let modified = false;
      
      // Calculate the depth change for relative imports
      const oldDepth = oldFilePath.split('/').length - 1;
      const newDepth = newFilePath.split('/').length - 1;
      const depthChange = newDepth - oldDepth;
      
      // Update relative imports
      content = content.replace(/from\s+(['"])(\.\.?\/[^'"]*)\1/g, (match, quote, importPath) => {
        if (depthChange === 0) {
          return match;
        }
        
        let newImportPath = importPath;
        if (depthChange > 0) {
          // Going deeper, add more ../
          newImportPath = '../'.repeat(depthChange) + importPath;
        } else {
          // Going shallower, remove ../
          const prefixToRemove = '../'.repeat(-depthChange);
          if (importPath.startsWith(prefixToRemove)) {
            newImportPath = importPath.substring(prefixToRemove.length);
            if (!newImportPath.startsWith('./') && !newImportPath.startsWith('../')) {
              newImportPath = './' + newImportPath;
            }
          }
        }
        
        if (newImportPath !== importPath) {
          modified = true;
          if (this.dryRun) {
            // eslint-disable-next-line no-console
            console.log(`   🔄 Would update import: ${importPath} -> ${newImportPath}`);
          } else {
            // eslint-disable-next-line no-console
            console.log(`   🔄 Updating import: ${importPath} -> ${newImportPath}`);
          }
          return `from ${quote}${newImportPath}${quote}`;
        }
        return match;
      });
      
      if (modified && !this.dryRun) {
        await fs.writeFile(fullFilePath, content, 'utf-8');
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(`   ⚠️  Error updating outgoing imports: ${error.message}`);
    }
  }

  async updateIncomingImports(oldFilePath, newFilePath) {
    try {
      const appFiles = await this.findJSFiles();
      const oldModuleName = this.filePathToModuleName(oldFilePath);
      const newModuleName = this.filePathToModuleName(newFilePath);
      
      for (const file of appFiles) {
        if (file === oldFilePath || file === newFilePath) {
          continue;
        }
        
        const fullPath = path.join(this.discourseAppPath, file);
        try {
          let content = await fs.readFile(fullPath, 'utf-8');
          let modified = false;
          
          // Update absolute imports (discourse module names)
          content = content.replace(
            new RegExp(`from\\s+(['"])${oldModuleName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\1`, 'g'),
            (match, quote) => {
              modified = true;
              if (this.dryRun) {
                // eslint-disable-next-line no-console
                console.log(`   🔄 Would update import in ${file}: ${oldModuleName} -> ${newModuleName}`);
              } else {
                // eslint-disable-next-line no-console
                console.log(`   🔄 Updating import in ${file}: ${oldModuleName} -> ${newModuleName}`);
              }
              return `from ${quote}${newModuleName}${quote}`;
            }
          );
          
          // Update relative imports
          const relativeOld = this.getRelativeImportPath(file, oldFilePath);
          const relativeNew = this.getRelativeImportPath(file, newFilePath);
          
          if (relativeOld !== relativeNew) {
            content = content.replace(
              new RegExp(`from\\s+(['"])${relativeOld.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\1`, 'g'),
              (match, quote) => {
                modified = true;
                if (this.dryRun) {
                  // eslint-disable-next-line no-console
                  console.log(`   🔄 Would update relative import in ${file}: ${relativeOld} -> ${relativeNew}`);
                } else {
                  // eslint-disable-next-line no-console
                  console.log(`   🔄 Updating relative import in ${file}: ${relativeOld} -> ${relativeNew}`);
                }
                return `from ${quote}${relativeNew}${quote}`;
              }
            );
          }
          
          if (modified && !this.dryRun) {
            await fs.writeFile(fullPath, content, 'utf-8');
          }
        } catch {
          // Skip files we can't read/write
        }
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.log(`   ⚠️  Error updating incoming imports: ${error.message}`);
    }
  }

  filePathToModuleName(filePath) {
    // Convert file path to Discourse module name
    // e.g., controllers/group-index.js -> discourse/controllers/group-index
    return 'discourse/' + filePath.replace(/\.(js|gjs)$/, '');
  }

  getRelativeImportPath(fromFile, toFile) {
    const fromDir = path.dirname(fromFile);
    const relativePath = path.relative(fromDir, toFile);
    
    // Normalize to use forward slashes and add ./ prefix if needed
    const normalized = relativePath.replace(/\\/g, '/').replace(/\.(js|gjs)$/, '');
    
    if (!normalized.startsWith('../') && !normalized.startsWith('./')) {
      return './' + normalized;
    }
    
    return normalized;
  }

  async findJSFiles() {
    const jsFiles = [];
    
    async function scanDir(dir) {
      try {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        
        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          
          if (entry.isDirectory()) {
            await scanDir(fullPath);
          } else if (entry.name.endsWith('.js') || entry.name.endsWith('.gjs')) {
            const relativePath = path.relative(this.discourseAppPath, fullPath);
            jsFiles.push(relativePath.replace(/\\/g, '/'));
          }
        }
      } catch {
        // Skip directories we can't read
      }
    }
    
    await scanDir.call(this, this.discourseAppPath);
    return jsFiles;
  }

  async createStubFile(type, resolverPath, isRelated = false) {
    const stubFilePath = this.resolverNameToFilePath(type, resolverPath);
    if (!stubFilePath) {
      return;
    }

    const fullStubPath = path.join(this.discourseAppPath, stubFilePath);

    try {
      // Check if stub file already exists
      await fs.access(fullStubPath);
      return; // Stub already exists, skip
    } catch {
      // File doesn't exist, create it
    }

    if (this.dryRun) {
      const prefix = isRelated ? "   📋 Would create related stub:" : "   📋 Would create stub:";
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
      await fs.writeFile(fullStubPath, stubContent, 'utf8');

      const prefix = isRelated ? "   📋 Created related stub:" : "   📋 Created stub:";
      // eslint-disable-next-line no-console
      console.log(`${prefix} ${stubFilePath}`);
    } catch (error) {
      this.errors.push(`Failed to create stub ${stubFilePath}: ${error.message}`);
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
