/*!
* lazyYT (lazy load YouTube videos)
* v1.0.1 - 2014-12-30
* (CC) This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
* http://creativecommons.org/licenses/by-sa/4.0/
* Contributors: https://github.com/tylerpearson/lazyYT/graphs/contributors || https://github.com/daugilas/lazyYT/graphs/contributors
*
* Usage: <div class="lazyYT" data-youtube-id="laknj093n" data-parameters="rel=0">loading...</div>
*/

;(function ($) {
  'use strict';

  function setUp($el, settings) {
    var width = $el.data('width'),
    height = $el.data('height'),
    ratio = ($el.data('ratio')) ? $el.data('ratio') : settings.default_ratio,
    id = $el.data('youtube-id'),
    title = $el.data('youtube-title'),
    padding_bottom,
    innerHtml = [],
    $thumb,
    thumb_img,
    youtube_parameters = $el.data('parameters') || '';

    ratio = ratio.split(":");

    // width and height might override default_ratio value
    if (typeof width === 'number' && typeof height === 'number') {
      $el.width(width);
      padding_bottom = height + 'px';
    } else if (typeof width === 'number') {
      $el.width(width);
      padding_bottom = (width * ratio[1] / ratio[0]) + 'px';
    } else {
      width = $el.width();

      // no width means that container is fluid and will be the size of its parent
      if (width === 0) {
        width = $el.parent().width();
      }

      padding_bottom = (ratio[1] / ratio[0] * 100) + '%';
    }

    //
    // This HTML will be placed inside 'lazyYT' container

    innerHtml.push('<div class="ytp-thumbnail">');

    // Play button from YouTube (exactly as it is in YouTube)
    innerHtml.push('<div class="ytp-large-play-button"');
    if (width <= 640) innerHtml.push(' style="transform: scale(0.563888888888889);"');
    innerHtml.push('>');
    innerHtml.push('<svg>');
    innerHtml.push('<path fill-rule="evenodd" clip-rule="evenodd" fill="#1F1F1F" class="ytp-large-play-button-svg" d="M84.15,26.4v6.35c0,2.833-0.15,5.967-0.45,9.4c-0.133,1.7-0.267,3.117-0.4,4.25l-0.15,0.95c-0.167,0.767-0.367,1.517-0.6,2.25c-0.667,2.367-1.533,4.083-2.6,5.15c-1.367,1.4-2.967,2.383-4.8,2.95c-0.633,0.2-1.316,0.333-2.05,0.4c-0.767,0.1-1.3,0.167-1.6,0.2c-4.9,0.367-11.283,0.617-19.15,0.75c-2.434,0.034-4.883,0.067-7.35,0.1h-2.95C38.417,59.117,34.5,59.067,30.3,59c-8.433-0.167-14.05-0.383-16.85-0.65c-0.067-0.033-0.667-0.117-1.8-0.25c-0.9-0.133-1.683-0.283-2.35-0.45c-2.066-0.533-3.783-1.5-5.15-2.9c-1.033-1.067-1.9-2.783-2.6-5.15C1.317,48.867,1.133,48.117,1,47.35L0.8,46.4c-0.133-1.133-0.267-2.55-0.4-4.25C0.133,38.717,0,35.583,0,32.75V26.4c0-2.833,0.133-5.95,0.4-9.35l0.4-4.25c0.167-0.966,0.417-2.05,0.75-3.25c0.7-2.333,1.567-4.033,2.6-5.1c1.367-1.434,2.967-2.434,4.8-3c0.633-0.167,1.333-0.3,2.1-0.4c0.4-0.066,0.917-0.133,1.55-0.2c4.9-0.333,11.283-0.567,19.15-0.7C35.65,0.05,39.083,0,42.05,0L45,0.05c2.467,0,4.933,0.034,7.4,0.1c7.833,0.133,14.2,0.367,19.1,0.7c0.3,0.033,0.833,0.1,1.6,0.2c0.733,0.1,1.417,0.233,2.05,0.4c1.833,0.566,3.434,1.566,4.8,3c1.066,1.066,1.933,2.767,2.6,5.1c0.367,1.2,0.617,2.284,0.75,3.25l0.4,4.25C84,20.45,84.15,23.567,84.15,26.4z M33.3,41.4L56,29.6L33.3,17.75V41.4z"></path>');
    innerHtml.push('<polygon fill-rule="evenodd" clip-rule="evenodd" fill="#FFFFFF" points="33.3,41.4 33.3,17.75 56,29.6"></polygon>');
    innerHtml.push('</svg>');
    innerHtml.push('</div>'); // end of .ytp-large-play-button

    innerHtml.push('</div>'); // end of .ytp-thumbnail

    // Video title (info bar)
    innerHtml.push('<div class="html5-info-bar">');
    innerHtml.push('<div class="html5-title">');
    innerHtml.push('<div class="html5-title-text-wrapper">');
    innerHtml.push('<a class="html5-title-text" target="_blank" tabindex="3100" href="https://www.youtube.com/watch?v=', id, '">');
    if (title === undefined || title === null || title === '') {
      innerHtml.push('youtube.com/watch?v=' + id);
    } else {
      innerHtml.push(title);
    }
    innerHtml.push('</a>');
    innerHtml.push('</div>'); // .html5-title
    innerHtml.push('</div>'); // .html5-title-text-wrapper
    innerHtml.push('</div>'); // end of Video title .html5-info-bar

    $el.css({
      'padding-bottom': padding_bottom
    })
    .html(innerHtml.join(''));

    if (width > 640) {
      thumb_img = 'maxresdefault.jpg';
    } else if (width > 480) {
      thumb_img = 'sddefault.jpg';
    } else if (width > 320) {
      thumb_img = 'hqdefault.jpg';
    } else if (width > 120) {
      thumb_img = 'mqdefault.jpg';
    } else if (width === 0) { // sometimes it fails on fluid layout
      thumb_img = 'hqdefault.jpg';
    } else {
      thumb_img = 'default.jpg';
    }

    $thumb = $el.find('.ytp-thumbnail').css({
      'background-image': ['url(//img.youtube.com/vi/', id, '/', thumb_img, ')'].join('')
    })
    .addClass('lazyYT-image-loaded')
    .on('click', function (e) {
      e.preventDefault();
      if (!$el.hasClass('lazyYT-video-loaded') && $thumb.hasClass('lazyYT-image-loaded')) {
        $el.html('<iframe src="//www.youtube.com/embed/' + id + '?autoplay=1&' + youtube_parameters + '" frameborder="0" allowfullscreen></iframe>')
        .addClass('lazyYT-video-loaded');
      }
    });

  }

  $.fn.lazyYT = function (newSettings) {
    var defaultSettings = {
      default_ratio: '16:9',
      callback: null, // ToDO execute callback if given
      container_class: 'lazyYT-container'
    };
    var settings = $.extend(defaultSettings, newSettings);

    return this.each(function () {
      var $el = $(this).addClass(settings.container_class);
      setUp($el, settings);
    });
  };

}(jQuery));
