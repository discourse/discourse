import path from "path";
import TemplateCompiler from "./raw-handlebars-compiler.js";

export default function transformHbr() {
  return {
    name: "transform-hbr",

    transform(src, id) {
      if (!id.endsWith(".hbr")) {
        return;
      }
      const relativePath = path.relative(process.cwd(), id);

      const pluginName = relativePath.match(
        /..\/..\/..\/plugins\/([^\/]+)\//
      )?.[1];

      let moduleName;

      if (pluginName) {
        // TODO
        moduleName = relativePath
          .replace(`discourse/plugins/${pluginName}/`, "")
          .replace(/^(discourse\/)?raw-templates\//, "javascripts/");
      } else {
        moduleName = relativePath.replace(/^app\//, "");
      }

      const newSrc = TemplateCompiler.prototype.processString(src, moduleName);

      return {
        code: newSrc,
      };

      // if(relative)
      // if (fileRegex.test(id)) {
      //   return {
      //     code: compileFileToJS(src),
      //     map: null, // provide source map if available
      //   };
      // }
    },
  };
}
