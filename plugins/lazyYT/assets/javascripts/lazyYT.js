/*! LazyYT (lazy load Youtube videos plugin) - v0.3.4 - 2014-06-30
* Usage: <div class="lazyYT" data-youtube-id="laknj093n" ratio="16:9" data-parameters="rel=0">loading...</div>
* Copyright (c) 2014 Tyler Pearson; Licensed MIT */


;(function ($) {
    'use strict';

    function setUp($el) {
        var width = $el.data('width'),
            height = $el.data('height'),
            ratio = $el.data('ratio'),
            id = $el.data('youtube-id'),
            aspectRatio = ['16', '9'],
            paddingTop = 0,
            youtubeParameters = $el.data('parameters') || '';

        if (typeof width === 'undefined' || typeof height === 'undefined') {
          height = 0;
          width = '100%';
          aspectRatio = (ratio.split(":")[1] / ratio.split(":")[0]) * 100;
          paddingTop = aspectRatio + '%';
        }

        $el.css({
            'position': 'relative',
            'height': height,
            'width': width,
            'padding-top': paddingTop,
            'background': 'url(//img.youtube.com/vi/' + id + '/hqdefault.jpg) center center no-repeat',
            'cursor': 'pointer',
            'background-size': 'cover'
        })
            .html('<p id="lazyYT-title-' + id + '" class="lazyYT-title"></p><div class="lazyYT-button"></div>')
            .addClass('lazyYT-image-loaded');
            
        var $el_title = $el.find("p.lazyYT-title");  //get reference to the current container title element
        
        $.getJSON('https://gdata.youtube.com/feeds/api/videos/' + id + '?v=2&alt=json', function (data) {
            $el_title.text(data.entry.title.$t); 
        });

        $el.on('click', function (e) {
            e.preventDefault();
            if (!$el.hasClass('lazyYT-video-loaded') && $el.hasClass('lazyYT-image-loaded')) {
                $el.html('<iframe width="' + width + '" height="' + height + '" src="//www.youtube.com/embed/' + id + '?autoplay=1&' + youtubeParameters + '" style="position:absolute; top:0; left:0; width:100%; height:100%;" frameborder="0" allowfullscreen></iframe>')
                    .removeClass('lazyYT-image-loaded')
                    .addClass('lazyYT-video-loaded');
            }
        });

    }

    $.fn.lazyYT = function () {
        return this.each(function () {
            var $el = $(this).css('cursor', 'pointer');
            setUp($el);
        });
    };

}(jQuery));
