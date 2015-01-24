$(function() {
  var delay = (function() {
    var timer = 0;
    return function(callback, ms){
      clearTimeout(timer);
      timer = setTimeout(callback, ms);
    };
  })();

  $('#onebox-url').keyup(function() {
    var input = $(this);
    delay(function() {
      url = input.val();
      $.ajax({
        url: '/onebox',
        type: 'GET',
        data: {
          url: url
        }
      }).done(function(data) {
        $('.onebox-container').empty().append(data.onebox);
        $('#oneboxed-url').empty().text(data.url);
        $('#onebox-engine').empty().text(data.engine);
        $('#preview-html').empty().text(data.onebox);
        $('#placeholder-html').empty().text(data.placeholder);
      });
    }, 500);
  });
});
