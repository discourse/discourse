(function() {

 var head = document.getElementsByTagName("head")[0], script;
  script = document.createElement("script");
  script.type = "text/x-mathjax-config";
  script[(window.opera ? "innerHTML" : "text")] =
    "MathJax.Hub.Config({\n" +
    "  tex2jax: { inlineMath: [['$$','$$'], ['\\\\(','\\\\)']] , ignoreClass: 'ember-application', processClass: 'preview-wrapper|cooked' }\n" +
    "}); \n" +
	"MathJax.Hub.Startup.onload();";
  head.appendChild(script);
  script = document.createElement("script");
  script.type = "text/javascript";
  script.src  = "http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML";
  head.appendChild(script);
  
    // Regiest a before cook event
  Discourse.Markdown.on("beforeCook", function(event) {
	MathJax.Hub.Queue(["Typeset",MathJax.Hub]);
  });
  

	  
}).call(this);
