export function isNthPost(every, currentPostNumber) {
  if (every && every > 0) {
    return currentPostNumber % every === 0;
  } else {
    return false;
  }
}

export function isNthTopicListItem(every, currentIndexPosition) {
  if (every && every > 0 && currentIndexPosition > 0) {
    return (currentIndexPosition + 1) % every === 0;
  } else {
    return false;
  }
}
