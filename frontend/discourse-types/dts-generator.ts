/**
 * Based on https://github.com/SitePen/dts-generator
 * The original package: © 2015-2019 SitePen, Inc. New BSD License.
 */
import { writeFileSync } from "node:fs";
import { EOL } from "node:os";
import * as path from "node:path";
import {
  type ExportDeclaration,
  type ImportDeclaration,
  type Node,
  type SourceFile,
  type StringLiteral,
  SyntaxKind,
} from "typescript/unstable/ast";
import { API } from "typescript/unstable/sync";

export interface ResolveModuleIdParams {
  /** The identifier of the module being declared in the generated d.ts */
  currentModuleId: string;
}

export interface ResolveModuleImportParams {
  /** The identifier of the module currently being imported in the generated d.ts */
  importedModuleId: string;

  /** The identifier of the enclosing module currently being declared in the generated d.ts */
  currentModuleId: string;
}

export interface Options {
  project: string;
  out: string;
  resolveModuleId: (params: ResolveModuleIdParams) => string;
  resolveModuleImport: (params: ResolveModuleImportParams) => string;
}

const DTSLEN = ".d.ts".length;

const filenameToMid: (filename: string) => string = (function () {
  if (path.sep === "/") {
    return (filename: string) => filename;
  } else {
    const separatorExpression = new RegExp(path.sep.replace("\\", "\\\\"), "g");
    return (filename: string) => filename.replace(separatorExpression, "/");
  }
})();

function processTree(
  sourceFile: SourceFile,
  replacer: (node: Node) => string | null
): string {
  let code = "";
  let cursorPosition = 0;

  function skip(node: Node) {
    cursorPosition = node.end;
  }

  function readThrough(node: Node) {
    code += sourceFile.text.slice(cursorPosition, node.pos);
    cursorPosition = node.pos;
  }

  function visit(node: Node) {
    readThrough(node);

    const replacement = replacer(node);

    if (replacement != null) {
      const start = node.getStart(sourceFile);
      code += sourceFile.text.slice(cursorPosition, start);
      code += replacement;
      skip(node);
    } else {
      node.forEachChild(visit);
    }
  }

  visit(sourceFile);
  code += sourceFile.text.slice(cursorPosition);

  return code;
}

function isNodeKindImportDeclaration(value: Node): value is ImportDeclaration {
  return value && value.kind === SyntaxKind.ImportDeclaration;
}

function isNodeKindStringLiteral(value: Node): value is StringLiteral {
  return value && value.kind === SyntaxKind.StringLiteral;
}

function isNodeKindExportDeclaration(value: Node): value is ExportDeclaration {
  return value && value.kind === SyntaxKind.ExportDeclaration;
}

export default function generate(options: Options): void {
  const nonEmptyLineStart = new RegExp(EOL + "(?!" + EOL + "|$)", "g");
  const indent = "\t";
  const baseDir = path.resolve(options.project);
  const output: string[] = [];

  const api = new API({ cwd: baseDir });
  try {
    const { fileNames } = api.parseJsonConfigFileContent(
      {},
      { configDirectory: baseDir }
    );
    const program = api.createProgram(fileNames, {});

    for (const fileName of program.getSourceFileNames()) {
      // Default libraries and other packages' files stay out of the bundle
      if (
        !path.normalize(fileName).startsWith(baseDir + path.sep) ||
        !fileName.endsWith(".d.ts")
      ) {
        continue;
      }

      writeDeclaration(program.getSourceFile(fileName)!);
    }
  } finally {
    api.close();
  }

  writeFileSync(options.out, output.join(""), { mode: 0o644 });

  function writeDeclaration(declarationFile: SourceFile) {
    // resolving is important for dealing with relative outDirs
    const filename = path.resolve(declarationFile.fileName);

    const sourceModuleId = filenameToMid(
      filename.slice(baseDir.length + 1, -DTSLEN)
    );
    const currentModuleId = filenameToMid(
      filename.slice(baseDir.length + 1, -DTSLEN)
    );

    function resolveModuleImport(moduleId: string): string {
      let resolved: string = options.resolveModuleImport({
        importedModuleId: moduleId,
        currentModuleId: currentModuleId,
      });

      if (!resolved) {
        // resolve relative imports relative to the current module id.
        if (moduleId.startsWith(".")) {
          resolved = filenameToMid(
            path.join(path.dirname(sourceModuleId), moduleId)
          );
        } else {
          resolved = moduleId;
        }
      }

      return resolved;
    }

    if (declarationFile.externalModuleIndicator) {
      const resolvedModuleId: string = options.resolveModuleId({
        currentModuleId: currentModuleId,
      });

      // Skip modules rejected by resolveModuleId callback
      if (!resolvedModuleId) {
        return;
      }

      output.push("declare module '" + resolvedModuleId + "' {" + EOL + indent);

      const content = processTree(declarationFile, function (node) {
        if (node.kind == SyntaxKind.DeclareKeyword) {
          return "";
        } else if (
          isNodeKindStringLiteral(node) &&
          node.parent &&
          (isNodeKindExportDeclaration(node.parent) ||
            isNodeKindImportDeclaration(node.parent))
        ) {
          // This block of code is modifying the names of imported modules
          const resolved: string = resolveModuleImport(node.text);
          if (resolved) {
            return ` '${resolved}'`;
          }
        }

        return null;
      });

      output.push(content.replace(nonEmptyLineStart, "$&" + indent));
      output.push(EOL + "}" + EOL);
    } else {
      output.push(declarationFile.text);
    }
  }
}
