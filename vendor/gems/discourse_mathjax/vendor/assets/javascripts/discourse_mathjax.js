(function() {

  		var Script = {
		  _loadedScripts: [],
		  include: function(script){
			// include script only once
			if (this._loadedScripts.include(script)){
			  return false;
			}
			// request file synchronous
			var code = new Ajax.Request(script, {
			  asynchronous: false, method: "GET",
			  evalJS: false, evalJSON: false
			}).transport.responseText;
			// eval code on global level
			if (Prototype.Browser.IE) {
			  window.execScript(code);
			} else if (Prototype.Browser.WebKit){
			  $$("head").first().insert(Object.extend(
				new Element("script", {type: "text/javascript"}), {text: code}
			  ));
			} else {
			  window.eval(code);
			}
			// remember included script
			this._loadedScripts.push(script);
		  }
		};
	Script.load("http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"); 
	MathJax.Hub.Config({
		  tex2jax: {
			ignoreClass: "ember-application",
			processClass: "preview-wrapper|cooked"
		  }
	});
	  
}).call(this);
