export function scrollTopFor(y) {
  return y - offsetCalculator(y);
}

export default function offsetCalculator(y) {
  const $header = $('header');
  const $container = $('.posts-wrapper');
  const containerOffset = $container.offset();

  let titleHeight = 0;
  const scrollTop = y || $(window).scrollTop();

  if (!containerOffset || scrollTop < containerOffset.top) {
    console.log("ADD height");
    titleHeight = $('#topic-title').height() || 0;
  }

  const rawWinHeight = $(window).height();
  const windowHeight = rawWinHeight - titleHeight;

  const eyeTarget = (windowHeight / 10);
  const headerHeight = $header.outerHeight(true);
  const expectedOffset = titleHeight - ($header.find('.contents').height() || 0) + (eyeTarget * 2);
  const ideal = headerHeight + ((expectedOffset < 0) ? 0 : expectedOffset);

  if ($container.length === 0) { return expectedOffset; }

  const topPos = $container.offset().top;

  const docHeight = $(document).height();
  let scrollPercent = Math.min((scrollTop / (docHeight-rawWinHeight)), 1.0);

  let inter = topPos - scrollTop + ($container.height() * scrollPercent);
  if (inter < headerHeight + eyeTarget) {
    inter = headerHeight + eyeTarget;
  }

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
