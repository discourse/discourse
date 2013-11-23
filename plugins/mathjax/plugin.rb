# name: MathJax support for Discourse
# version: 0.1
# authors: Sam Saffron

register_asset('javascripts/tex_dialect.js', :server_side)
register_javascript <<JS 

    Discourse.addInitializer(function () {

      $LAB.script('http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML').wait(function() {

	    MathJax.Hub.Config({"HTML-CSS": { preferredFont: "TeX", availableFonts: ["STIX","TeX"], linebreaks: { automatic:true }, EqnChunk: (MathJax.Hub.Browser.isMobile ? 10 : 50) },
        tex2jax: { inlineMath: [ ["$", "$"], ["\\(","\\)"] ], displayMath: [ ["$$","$$"], ["\\[", "\\]"] ], processEscapes: true, ignoreClass: "tex2jax_ignore|dno" },
        TeX: {  noUndefined: { attributes: { mathcolor: "red", mathbackground: "#FFEEEE", mathsize: "90%" } }, Macros: { href: "{}" } },
        messageStyle: "none"
        });
        
		var applyPreview = _.debounce(function(){
          MathJax.Hub.Queue(["Typeset",MathJax.Hub,"wmd-preview"]);
        }, 500);

        var applyBody = function(){
          MathJax.Hub.Queue(["Typeset",MathJax.Hub,"topic"]);
        };

        Discourse.PostView.prototype.on("postViewInserted", applyBody);
        Discourse.ComposerView.prototype.on("previewRefreshed", applyPreview);

      });

    });
JS