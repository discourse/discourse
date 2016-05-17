export default function offsetCalculator() {
  const $header = $('header');
  const $title = $('#topic-title');
  const windowHeight = $(window).height() - $title.height();
  const expectedOffset = $title.height() - $header.find('.contents').height() + (windowHeight / 5);

  return $header.outerHeight(true) + ((expectedOffset < 0) ? 0 : expectedOffset);
}
