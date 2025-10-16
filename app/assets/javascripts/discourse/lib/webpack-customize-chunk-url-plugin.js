const pluginName = "CustomizeChunkUrlPlugin";

export class CustomizeChunkUrlPlugin {
  apply(compiler) {
    compiler.hooks.thisCompilation.tap(pluginName, (compilation) => {
      const { mainTemplate, runtimeTemplate } = compilation;
      mainTemplate.hooks.localVars.tap(
        { name: pluginName, stage: 1 },
        (source) => {
          return `
            ${source}
            (function(){
              // Rewrite chunk URLs to match the encoding of the current script
              if(typeof __webpack_require__ !== "undefined") {
                const currentScriptUrl = document.currentScript.src;

                let targetExt = ".js";
                if(currentScriptUrl.endsWith(".br.js")) {
                  targetExt = ".br.js";
                }else if(currentScriptUrl.endsWith(".gz.js")) {
                  targetExt = ".gz.js";
                }

                var oldGetScript = __webpack_require__.u;
                __webpack_require__.u = function(chunkId){
                  var result = oldGetScript(chunkId);
                  return result.replace(/\.js$/, targetExt);
                };
              };
            })();
          `;
        }
      );
    });
  }
}
