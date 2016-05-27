export default function offsetCalculator() {
  const $header = $('header');
  const $title = $('#topic-title');
  const rawWinHeight = $(window).height();
  const windowHeight = rawWinHeight - $title.height();
  const expectedOffset = $title.height() - $header.find('.contents').height() + (windowHeight / 5);
  const ideal = $header.outerHeight(true) + ((expectedOffset < 0) ? 0 : expectedOffset);

  const $container = $('.posts-wrapper');
  const topPos = $container.offset().top;

  const scrollTop = $(window).scrollTop();
  const docHeight = $(document).height();
  const scrollPercent = (scrollTop / (docHeight-rawWinHeight));

  const inter = topPos - scrollTop + ($container.height() * scrollPercent);

  if (inter > ideal) {
    const bottom = $('#topic-bottom').offset().top;
    if (bottom > (scrollTop + rawWinHeight)) {
      return ideal;
    }
  }

  return inter;
}
