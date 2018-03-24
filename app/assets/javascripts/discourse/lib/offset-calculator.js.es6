export function scrollTopFor(y) {
  return y - offsetCalculator(y);
}

export default function offsetCalculator(y) {
  const $header = $('header');
  const $container = $('.posts-wrapper');
  const scrollTop = y || $(window).scrollTop();
  const titleHeight = $('#topic-title').height() || 0;
  const rawWinHeight = $(window).height();
  const expectedOffset = titleHeight - ($header.find('.contents').height() || 0);

  if ($container.length === 0) { return expectedOffset; }

  const headerHeight = $header.outerHeight(true);
  const ideal = headerHeight + Math.max(0, expectedOffset);
  const topPos = $container.offset().top;
  const docHeight = $(document).height();
  const scrollPercent = Math.min(scrollTop / (docHeight - rawWinHeight), 1.0);
  const inter = Math.min(headerHeight, topPos - scrollTop + ($container.height() * scrollPercent));

  if (inter > ideal) {
    const bottom = $('#topic-bottom').offset().top;
    const switchPos = bottom - rawWinHeight - ideal;

    if (scrollTop > switchPos) {
      const p = Math.max(Math.min((scrollTop + inter - switchPos) / rawWinHeight, 1.0), 0.0);
      return ((1 - p) * ideal) + (p * inter);
    } else {
      return ideal;
    }
  }

  return inter;
}
