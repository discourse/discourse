/**
* jQuery Favicon Notify
*
* Updates the favicon with a number to notify the user of changes.
*
* iconUrl: Url of favicon image or icon
* count:   Integer count to place above favicon
*
* $.faviconNotify(iconUrl, count)
*/
(function($){
  $.faviconNotify = function(iconUrl, count){
    var canvas = canvas || $('<canvas />')[0],
        img = $('<img />')[0],
        multiplier, fontSize, context, xOffset, yOffset;

    if (canvas.getContext) {
           if (count < 1)  { count = '' }
      else if (count < 10) { count = ' ' + count }
      else if (count > 99) { count = '99' }

      img.onload = function () {
        canvas.height = canvas.width = this.width;
        multiplier = (this.width / 16);

        fontSize = multiplier * 11;
        xOffset  = multiplier;
        yOffset  = multiplier * 11;

        context = canvas.getContext('2d');
        context.drawImage(this, 0, 0);
        context.font = 'bold ' + fontSize + 'px "helvetica", sans-serif';

        context.fillStyle = '#FFF';
        context.fillText(count, xOffset, yOffset);
        context.fillText(count, xOffset + 2, yOffset);
        context.fillText(count, xOffset, yOffset + 2);
        context.fillText(count, xOffset + 2, yOffset + 2);

        context.fillStyle = '#000';
        context.fillText(count, xOffset + 1, yOffset + 1);

        $('link[rel$=icon]').remove();
        $('head').append(
          $('<link rel="shortcut icon" type="image/x-icon"/>').attr(
            'href', canvas.toDataURL('image/png')
          )
        );
      };
      img.src = iconUrl;
    }
  };
})(jQuery);
