import * as fs from "fs";
import * as glob from "glob";
import * as mkdirp from "mkdirp";
import * as os from "os";
import * as pathUtil from "path";
import * as ts from "typescript";

export interface ResolveModuleIdParams {
  /** The identifier of the module being declared in the generated d.ts */
  currentModuleId: string;
}

export interface ResolveModuleImportParams {
  /** The identifier of the module currently being imported in the generated d.ts */
  importedModuleId: string;

  /** The identifier of the enclosing module currently being declared in the generated d.ts */
  currentModuleId: string;

  /** True if the imported module id is declared as a module in the input files. */
  isDeclaredExternalModule: boolean;
}

export interface Options {
  project: string;
  out: string;
  resolveModuleId: (params: ResolveModuleIdParams) => string;
  resolveModuleImport: (params: ResolveModuleImportParams) => string;
}

const filenameToMid: (filename: string) => string = (function () {
  if (pathUtil.sep === "/") {
    return function (filename: string) {
      return filename;
    };
  } else {
    const separatorExpression = new RegExp(
      pathUtil.sep.replace("\\", "\\\\"),
      "g"
    );
    return function (filename: string) {
      return filename.replace(separatorExpression, "/");
    };
  }
})();

/**
 * A helper function that takes TypeScript diagnostic errors and returns an error
 * object.
 * @param diagnostics The array of TypeScript Diagnostic objects
 */
function getError(diagnostics: ts.Diagnostic[]) {
  let message = "Declaration generation failed";

  diagnostics.forEach(function (diagnostic) {
    // not all errors have an associated file: in particular, problems with a
    // the tsconfig.json don't; the messageText is enough to diagnose in those
    // cases.
    if (diagnostic.file && diagnostic.start !== undefined) {
      const position = diagnostic.file.getLineAndCharacterOfPosition(
        diagnostic.start
      );

      message +=
        `\n${diagnostic.file.fileName}(${position.line + 1},${position.character + 1}): ` +
        `error TS${diagnostic.code}: ${diagnostic.messageText}`;
    } else {
      message += `\nerror TS${diagnostic.code}: ${diagnostic.messageText}`;
    }
  });

  const error = new Error(message);
  error.name = "EmitterError";
  return error;
}

function getFilenames(baseDir: string, files: string[]): string[] {
  return files.map(function (filename) {
    const resolvedFilename = pathUtil.resolve(filename);
    if (resolvedFilename.startsWith(baseDir)) {
      return resolvedFilename;
    }

    return pathUtil.resolve(baseDir, filename);
  });
}

function processTree(
  sourceFile: ts.SourceFile,
  replacer: (node: ts.Node) => string | null
): string {
  let code = "";
  let cursorPosition = 0;

  function skip(node: ts.Node) {
    cursorPosition = node.end;
  }

  function readThrough(node: ts.Node) {
    code += sourceFile.text.slice(cursorPosition, node.pos);
    cursorPosition = node.pos;
  }

  function visit(node: ts.Node) {
    readThrough(node);

    const replacement = replacer(node);

    if (replacement != null) {
      code += replacement;
      skip(node);
    } else {
      ts.forEachChild(node, visit);
    }
  }

  visit(sourceFile);
  code += sourceFile.text.slice(cursorPosition);

  return code;
}

function isNodeKindImportDeclaration(
  value: ts.Node
): value is ts.ImportDeclaration {
  return value && value.kind === ts.SyntaxKind.ImportDeclaration;
}

function isNodeKindExternalModuleReference(
  value: ts.Node
): value is ts.ExternalModuleReference {
  return value && value.kind === ts.SyntaxKind.ExternalModuleReference;
}

function isNodeKindStringLiteral(value: ts.Node): value is ts.StringLiteral {
  return value && value.kind === ts.SyntaxKind.StringLiteral;
}

function isNodeKindExportDeclaration(
  value: ts.Node
): value is ts.ExportDeclaration {
  return value && value.kind === ts.SyntaxKind.ExportDeclaration;
}

function isNodeKindExportAssignment(
  value: ts.Node
): value is ts.ExportAssignment {
  return value && value.kind === ts.SyntaxKind.ExportAssignment;
}

function isNodeKindModuleDeclaration(
  value: ts.Node
): value is ts.ModuleDeclaration {
  return value && value.kind === ts.SyntaxKind.ModuleDeclaration;
}

export default function generate(options: Options): Promise<void> {
  const result = ts.parseConfigFileTextToJson("tsconfig.json", "{}");
  const configParseResult = ts.parseJsonConfigFileContent(
    result.config,
    ts.sys,
    options.project.slice(0, -1)
  );

  const compilerOptions: ts.CompilerOptions = configParseResult.options;
  const files: string[] = configParseResult.fileNames;
  const eol = os.EOL;
  const nonEmptyLineStart = new RegExp(eol + "(?!" + eol + "|$)", "g");
  const indent = "\t";

  // use input values if tsconfig leaves any of these undefined.
  // this is for backwards compatibility
  compilerOptions.declaration = true;
  compilerOptions.target = ts.ScriptTarget.Latest; // is this necessary?

  const baseDir = pathUtil.resolve(options.project);
  const outDir = compilerOptions.outDir;

  const filenames = getFilenames(baseDir, files);
  mkdirp.sync(pathUtil.dirname(options.out));

  const output = fs.createWriteStream(options.out, {
    mode: parseInt("644", 8),
  });
  const host = ts.createCompilerHost(compilerOptions);
  const program = ts.createProgram(filenames, compilerOptions, host);

  function writeFile(filename: string, data: string) {
    // Compiler is emitting the non-declaration file, which we do not care about
    if (!filename.endsWith(".d.ts")) {
      return;
    }

    writeDeclaration(
      ts.createSourceFile(filename, data, compilerOptions.target!, true),
      true
    );
  }

  let declaredExternalModules: string[] = [];

  return new Promise<void>(function (resolve, reject) {
    output.on("close", () => {
      resolve(undefined);
    });
    output.on("error", reject);

    program.getSourceFiles().forEach(function (sourceFile) {
      processTree(sourceFile, function (node) {
        if (isNodeKindModuleDeclaration(node)) {
          const name = node.name;
          if (isNodeKindStringLiteral(name)) {
            declaredExternalModules.push(name.text);
          }
        }
        return null;
      });
    });

    program.getSourceFiles().some(function (sourceFile) {
      // Source file is a default library, or other dependency from another project, that should not be included in
      // our bundled output
      if (
        !pathUtil
          .normalize(sourceFile.fileName)
          .startsWith(baseDir + pathUtil.sep)
      ) {
        return;
      }

      // Source file is already a declaration file so should does not need to be pre-processed by the emitter
      if (sourceFile.fileName.endsWith(".d.ts")) {
        writeDeclaration(sourceFile, false);
        return;
      }

      const emitOutput = program.emit(sourceFile, writeFile);
      if (emitOutput.emitSkipped || emitOutput.diagnostics.length > 0) {
        reject(
          getError(
            emitOutput.diagnostics
              .concat(program.getSemanticDiagnostics(sourceFile))
              .concat(program.getSyntacticDiagnostics(sourceFile))
              .concat(program.getDeclarationDiagnostics(sourceFile))
          )
        );

        return true;
      }
    });

    output.end();
  });

  function writeDeclaration(declarationFile: ts.SourceFile, isOutput: boolean) {
    // resolving is important for dealing with relative outDirs
    const filename = pathUtil.resolve(declarationFile.fileName);

    // use the outDir here, not the baseDir, because the declarationFiles are
    // outputs of the build process; baseDir points instead to the inputs.
    // However we have to account for .d.ts files in our inputs that this code
    // is also used for.  Also if no outDir is used, the compiled code ends up
    // alongside the source, so use baseDir in that case too.
    const outputDir =
      isOutput && Boolean(outDir) ? pathUtil.resolve(outDir!) : baseDir;

    const DTSLEN = ".d.ts".length;
    const sourceModuleId = filenameToMid(
      filename.slice(outputDir.length + 1, -DTSLEN)
    );
    const currentModuleId = filenameToMid(
      filename.slice(outputDir.length + 1, -DTSLEN)
    );

    function resolveModuleImport(moduleId: string): string {
      const isDeclaredExternalModule: boolean =
        declaredExternalModules.includes(moduleId);
      let resolved: string = options.resolveModuleImport({
        importedModuleId: moduleId,
        currentModuleId: currentModuleId,
        isDeclaredExternalModule: isDeclaredExternalModule,
      });

      if (!resolved) {
        // resolve relative imports relative to the current module id.
        if (moduleId.charAt(0) === ".") {
          resolved = filenameToMid(
            pathUtil.join(pathUtil.dirname(sourceModuleId), moduleId)
          );
        } else {
          resolved = moduleId;
        }
      }

      return resolved;
    }

    /* For some reason, SourceFile.externalModuleIndicator is missing from 1.6+, so having
     * to use a sledgehammer on the nut */
    if ((<any>declarationFile).externalModuleIndicator) {
      let resolvedModuleId: string = sourceModuleId;
      if (options.resolveModuleId) {
        const resolveModuleIdResult: string = options.resolveModuleId({
          currentModuleId: currentModuleId,
        });
        if (resolveModuleIdResult) {
          resolvedModuleId = resolveModuleIdResult;
        }
      }

      output.write(
        "declare module '" + resolvedModuleId + "' {" + eol + indent
      );

      const content = processTree(declarationFile, function (node) {
        if (isNodeKindExternalModuleReference(node)) {
          // TODO figure out if this branch is possible, and if so, write a test
          // that covers it.

          const expression = node.expression as ts.LiteralExpression;

          // convert both relative and non-relative module names in import = require(...)
          // statements.
          const resolved: string = resolveModuleImport(expression.text);
          return ` require('${resolved}')`;
        } else if (node.kind == ts.SyntaxKind.DeclareKeyword) {
          return "";
        } else if (
          isNodeKindStringLiteral(node) &&
          node.parent &&
          (isNodeKindExportDeclaration(node.parent) ||
            isNodeKindImportDeclaration(node.parent))
        ) {
          // This block of code is modifying the names of imported modules
          const text = node.text;
          const resolved: string = resolveModuleImport(text);
          if (resolved) {
            return ` '${resolved}'`;
          }
        }

        return null;
      });

      output.write(content.replace(nonEmptyLineStart, "$&" + indent));
      output.write(eol + "}" + eol);
    } else {
      output.write(declarationFile.text);
    }
  }
}
