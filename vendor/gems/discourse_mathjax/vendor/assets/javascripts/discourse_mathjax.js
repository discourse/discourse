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
	  script.src  = "https://c328740.ssl.cf1.rackcdn.com/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML";
	  head.appendChild(script);
  

  
	var mathJaxProcessingTimer;
	

	$("#main").bind("DOMSubtreeModified", function() {
		if(mathJaxProcessingTimer != null){
			clearInterval(mathJaxProcessingTimer);
		}
		mathJaxProcessingTimer = setInterval(function(){ MathJax.Hub.Queue(["Typeset",MathJax.Hub,"topic"]);MathJax.Hub.Queue(["Typeset",MathJax.Hub,"wmd-preview"]);},1000);
	});

}).call(this);

