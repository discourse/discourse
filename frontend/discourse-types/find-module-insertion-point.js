import { parse } from "@babel/parser";
import traverseModule from "@babel/traverse";

/** @type {typeof traverseModule} */
const traverse = traverseModule.default || traverseModule;

export default function findModuleInsertionPoint(dts) {
  let ast;
  try {
    ast = parse(dts, {
      sourceType: "module",
      plugins: [["typescript", { dts: true }]],
    });
  } catch {
    return 0;
  }

  let positionAfterLastImport;

  traverse(ast, {
    ImportDeclaration(path) {
      positionAfterLastImport = path.node.end;
    },
  });

  return positionAfterLastImport || 0;
}
