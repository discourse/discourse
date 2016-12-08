/**
 * jQuery iframe click tracking plugin
 *
 * @author Vincent Paré (www.finalclap.com)
 * @copyright © 2013-2015 Vincent Paré
 * @license http://opensource.org/licenses/Apache-2.0
 * @version 1.1.0
 */
(function($){
	// Tracking handler manager
	$.fn.iframeTracker = function(handler){
		var target = this.get();
		if (handler === null || handler === false) {
			$.iframeTracker.untrack(target);
		} else if (typeof handler == "object") {
			$.iframeTracker.track(target, handler);
		} else {
			throw new Error("Wrong handler type (must be an object, or null|false to untrack)");
		}
	};
	
	// Iframe tracker common object
	$.iframeTracker = {
		// State
		focusRetriever: null,  // Element used for restoring focus on window (element)
		focusRetrieved: false, // Says if the focus was retrived on the current page (bool)
		handlersList: [],      // Store a list of every trakers (created by calling $(selector).iframeTracker...)
		isIE8AndOlder: false,  // true for Internet Explorer 8 and older
		
		// Init (called once on document ready)
		init: function(){
			// Determine browser version (IE8-) ($.browser.msie is deprecated since jQuery 1.9)
			try {
				if ($.browser.msie == true && $.browser.version < 9) {
					this.isIE8AndOlder = true;
				}
			} catch(ex) {
				try {
					var matches = navigator.userAgent.match(/(msie) ([\w.]+)/i);
					if (matches[2] < 9) {
						this.isIE8AndOlder = true;
					}
				} catch(ex2) {}
			}
			
			// Listening window blur
			$(window).focus();
			$(window).blur(function(e){
				$.iframeTracker.windowLoseFocus(e);
			});
			
			// Focus retriever (get the focus back to the page, on mouse move)
			$('body').append('<div style="position:fixed; top:0; left:0; overflow:hidden;"><input style="position:absolute; left:-300px;" type="text" value="" id="focus_retriever" readonly="true" /></div>');
			this.focusRetriever = $('#focus_retriever');
			this.focusRetrieved = false;
			$(document).mousemove(function(e){
				if (document.activeElement && document.activeElement.tagName == 'IFRAME') {
					$.iframeTracker.focusRetriever.focus();
					$.iframeTracker.focusRetrieved = true;
				}
			});
			
			// Special processing to make it work with my old friend IE8 (and older) ;)
			if (this.isIE8AndOlder) {
				// Blur doesn't works correctly on IE8-, so we need to trigger it manually
				this.focusRetriever.blur(function(e){
					e.stopPropagation();
					e.preventDefault();
					$.iframeTracker.windowLoseFocus(e);
				});
				
				// Keep focus on window (fix bug IE8-, focusable elements)
				$('body').click(function(e){ $(window).focus(); });
				$('form').click(function(e){ e.stopPropagation(); });
				
				// Same thing for "post-DOMready" created forms (issue #6)
				try {
					$('body').on('click', 'form', function(e){ e.stopPropagation(); });
				} catch(ex) {
					console.log("[iframeTracker] Please update jQuery to 1.7 or newer. (exception: " + ex.message + ")");
				}
			}
		},
		
		
		// Add tracker to target using handler (bind boundary listener + register handler)
		// target: Array of target elements (native DOM elements)
		// handler: User handler object
		track: function(target, handler){
			// Adding target elements references into handler
			handler.target = target;
			
			// Storing the new handler into handler list
			$.iframeTracker.handlersList.push(handler);
			
			// Binding boundary listener
			$(target)
				.bind('mouseover', {handler: handler}, $.iframeTracker.mouseoverListener)
				.bind('mouseout',  {handler: handler}, $.iframeTracker.mouseoutListener);
		},
		
		// Remove tracking on target elements
		// target: Array of target elements (native DOM elements)
		untrack: function(target){
			if (typeof Array.prototype.filter != "function") {
				console.log("Your browser doesn't support Array filter, untrack disabled");
				return;
			}
			
			// Unbinding boundary listener
			$(target).each(function(index){
				$(this)
					.unbind('mouseover', $.iframeTracker.mouseoverListener)
					.unbind('mouseout', $.iframeTracker.mouseoutListener);
			});
			
			// Handler garbage collector
			var nullFilter = function(value){
				return value === null ? false : true;
			};
			for (var i in this.handlersList) {
				// Prune target
				for (var j in this.handlersList[i].target) {
					if ($.inArray(this.handlersList[i].target[j], target) !== -1) {
						this.handlersList[i].target[j] = null;
					}
				}
				this.handlersList[i].target = this.handlersList[i].target.filter(nullFilter);
				
				// Delete handler if unused
				if (this.handlersList[i].target.length == 0) {
					this.handlersList[i] = null;
				}
			}
			this.handlersList = this.handlersList.filter(nullFilter);
		},
		
		// Target mouseover event listener
		mouseoverListener: function(e){
			e.data.handler.over = true;
			try {e.data.handler.overCallback(this);} catch(ex) {}
		},
		
		// Target mouseout event listener
		mouseoutListener: function(e){
			e.data.handler.over = false;
			$.iframeTracker.focusRetriever.focus();
			try {e.data.handler.outCallback(this);} catch(ex) {}
		},
		
		// Calls blurCallback for every handler with over=true on window blur
		windowLoseFocus: function(event){
			for (var i in this.handlersList) {
				if (this.handlersList[i].over == true) {
					try {this.handlersList[i].blurCallback();} catch(ex) {}
				}
			}
		}
	};
	
	// Init the iframeTracker on document ready
	$(document).ready(function(){
		$.iframeTracker.init();
	});
})(jQuery);