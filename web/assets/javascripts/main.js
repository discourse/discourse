$(function() {
  var updateView = function() {
    $.ajax({
      url: '/onebox',
      type: 'GET',
      data: {
        url: input.val()
      }
    }).done(function(data) {
      $('.onebox-container').empty().append(data.onebox).append(data.placeholder);
      $('#oneboxed-url').empty().text(data.url);
      $('#onebox-engine').empty().text(data.engine);
      $('#preview-html').empty().text(data.onebox);
      $('#placeholder-html').empty().text(data.placeholder);
    });
  };

  var input = $('#onebox-url').keyup(function(e) {
    // ENTER key
    if (e.keyCode === 13) { updateView(); }
  }).focus();
  $('#go').click(updateView);
});
