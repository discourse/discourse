// TODO: This is quite ugly but seems reasonably fast? Maybe refactor
// this out before we merge into stable.
export function scrollTopFor(y) {
  let off = 0;
  for (let i=0; i<3; i++) {
    off = offsetCalculator(y - off);
  }
  return off;
}

export default function offsetCalculator(y) {
  const $header = $('header');
  const $title = $('#topic-title');
  const rawWinHeight = $(window).height();
  const windowHeight = rawWinHeight - $title.height();
  const expectedOffset = $title.height() - $header.find('.contents').height() + (windowHeight / 5);
  const ideal = $header.outerHeight(true) + ((expectedOffset < 0) ? 0 : expectedOffset);

  const $container = $('.posts-wrapper');
  const topPos = $container.offset().top;

  const scrollTop = y || $(window).scrollTop();
  const docHeight = $(document).height();
  const scrollPercent = (scrollTop / (docHeight-rawWinHeight));

  const inter = topPos - scrollTop + ($container.height() * scrollPercent);

  if (inter > ideal) {
    const bottom = $('#topic-bottom').offset().top;
    const switchPos = bottom - rawWinHeight;
    if (scrollTop > switchPos) {
      const p = Math.max(Math.min((scrollTop + inter - switchPos) / rawWinHeight, 1.0), 0.0);
      return ((1 - p) * ideal) + (p * inter);
    } else {
      return ideal;
    }
  }

  return inter;
}
