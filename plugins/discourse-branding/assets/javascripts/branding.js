(function ($) {
  'use strict';

  $(window).scroll(function(){
    var fromTop = $(window).scrollTop();
    var marginTop = 0;
    if(fromTop < 48) {
       marginTop = 48 - fromTop;
    } else {
       marginTop = 0;
    }
    $(".branding header.d-header").css('margin-top', marginTop + 'px');
  });

})(jQuery);
