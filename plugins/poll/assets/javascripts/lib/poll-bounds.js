/**
 * How many options a poll accepts, given what its markup carries. Both bounds
 * are optional there: no minimum means one, and no maximum, or one past the
 * options that exist, means all of them.
 *
 * @param {{ min?: string|number, max?: string|number }} poll
 * @param {number} optionCount
 * @returns {{ min: number, max: number }}
 */
export default function pollBounds(poll, optionCount) {
  const min = parseInt(poll.min, 10);
  const max = parseInt(poll.max, 10);

  return {
    min: isNaN(min) || min < 0 ? 1 : min,
    max: isNaN(max) || max > optionCount ? optionCount : max,
  };
}
