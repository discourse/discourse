/**
 * jQuery Favicon Notify
 *
 * Updates the favicon to notify the user of changes. In the original tests I
 * had an embedded font collection to allow any charachers - I decided that the
 * ~130Kb and added complexity was overkill. As such it now uses a manual glyph
 * set meaning that only numerical notifications are possible.
 *
 * Dual licensed under the MIT and GPL licenses:
 *
 *		http://www.opensource.org/licenses/mit-license.php
 *		http://www.gnu.org/licenses/gpl.html
 *
 * @author		David King
 * @copyright	Copyright (c) 2011 +
 * @url			oodavid.com
 */
(function($){
	var canvas;
	var bg		= '#000000';
	var fg		= '#FFFFFF';
	var pos		= 'br';
	$.faviconNotify = function(icon, num, myPos, myBg, myFg){
		// Default the positions
		myPos	= myPos	|| pos;
		myFg	= myFg	|| fg;
		myBg	= myBg	|| bg;
		// Create a canvas if we need one
		canvas = canvas || $('<canvas />')[0];
		if(canvas.getContext){
			// Load the icon
			$('<img />').load(function(e){
				// Load the icon into the canvas
				canvas.height = canvas.width = 16;
				var ctx = canvas.getContext('2d');
				ctx.clearRect(0, 0, canvas.width, canvas.height);
				ctx.drawImage(this, 0, 0);
				// We gots num?
				if(num !== undefined){
					num = parseFloat(num, 10);
					// Convert the num into a glyphs array
					var myGlyphs = [];
					if(num > 99){
						myGlyphs.push(glyphs['LOTS']);
					} else {
						num = num.toString().split('');
						$.each(num, function(k,v){
							myGlyphs.push(glyphs[v]);
						});
					}
					// Merge the glyphs together
					var combined = [];
					var glyphHeight = myGlyphs[0].length;
					$.each(myGlyphs, function(k,v){
						for(y=0; y<glyphHeight; y++){
							// First pass?
							if(combined[y] === undefined) {
								combined[y] = v[y];
							} else {
								// Merge the glyph parts, careful of the boundaries
								var l = combined[y].length;
								if(combined[y][(l-1)] == ' '){
									combined[y] = combined[y].substring(0, (l-1)) + v[y];
								} else {
									combined[y] += v[y].substring(1);
								}
							}
						}
					});
					// Figure out our starting position
					var glyphWidth = combined[0].length;
					var x = (myPos.indexOf('l') != -1) ? 0 : (16 - glyphWidth);
					var y = (myPos.indexOf('t') != -1) ? 0 : (16 - glyphHeight);
					// Draw them pixels!
					for(dX=0; dX<glyphWidth; dX++){
						for(dY=0; dY<glyphHeight; dY++){
							var pixel = combined[dY][dX];
							if(pixel != ' '){
								ctx.fillStyle = (pixel == '@') ? myFg : myBg;
								ctx.fillRect((x+dX), (y+dY), 1, 1);
							}
						}
					}
				}
				// Update the favicon
				$('link[rel$=icon]').remove();
				$('head').append($('<link rel="shortcut icon" type="image/x-icon"/>').attr('href', canvas.toDataURL('image/png')));
			}).attr('src', icon)
		}
	};
	var glyphs	= {
		'0': [
			'  ---  ',
			' -@@@- ',
			'-@---@-',
			'-@- -@-',
			'-@- -@-',
			'-@- -@-',
			'-@---@-',
			' -@@@- ',
			'  ---  ' ],
		'1': [
			'  -  ',
			' -@- ',
			'-@@- ',
			' -@- ',
			' -@- ',
			' -@- ',
			' -@- ',
			'-@@@-',
			' --- ' ],
		'2': [
			'  ---  ',
			' -@@@- ',
			'-@---@-',
			' - --@-',
			'  -@@- ',
			' -@--  ',
			'-@---- ',
			'-@@@@@-',
			' ----- ' ],
		'3': [
			'  ---  ',
			' -@@@- ',
			'-@---@-',
			' - --@-',
			'  -@@- ',
			' - --@-',
			'-@---@-',
			' -@@@- ',
			'  ---  ' ],
		'4': [
			'    -- ',
			'   -@@-',
			'  -@-@-',
			' -@--@-',
			'-@---@-',
			'-@@@@@-',
			' ----@-',
			'    -@-',
			'     - ' ],
		'5': [
			' ----- ',
			'-@@@@@-',
			'-@---- ',
			'-@---  ',
			'-@@@@- ',
			' ----@-',
			'-@---@-',
			' -@@@- ',
			'  ---  ' ],
		'6': [
			'  ---  ',
			' -@@@- ',
			'-@---@-',
			'-@---- ',
			'-@@@@- ',
			'-@---@-',
			'-@---@-',
			' -@@@- ',
			'  ---  ' ],
		'7': [
			' ----- ',
			'-@@@@@-',
			' ----@-',
			'   -@- ',
			'   -@- ',
			'  -@-  ',
			'  -@-  ',
			'  -@-  ',
			'   -   ' ],
		'8': [
			'  ---  ',
			' -@@@- ',
			'-@---@-',
			'-@---@-',
			' -@@@- ',
			'-@---@-',
			'-@---@-',
			' -@@@- ',
			'  ---  ' ],
		'9': [
			'  ---  ',
			' -@@@- ',
			'-@---@-',
			'-@---@-',
			' -@@@@-',
			' ----@-',
			'-@---@-',
			' -@@@- ',
			'  ---  ' ],
		'!': [
			' - ',
			'-@-',
			'-@-',
			'-@-',
			'-@-',
			'-@-',
			' - ',
			'-@-',
			' - ' ],
		'.': [
			'   ',
			'   ',
			'   ',
			'   ',
			'   ',
			'   ',
			' - ',
			'-@-',
			' - ' ],
		'LOTS': [
			' -   -- ---  -- ',
			'-@- -@@-@@@--@@-',
			'-@--@--@-@--@-  ',
			'-@--@--@-@--@-  ',
			'-@--@--@-@- -@- ',
			'-@--@--@-@-  -@-',
			'-@--@--@-@----@-',
			'-@@@-@@--@-@@@- ',
			' --- --  - ---  '
		]
	};
})(jQuery);
