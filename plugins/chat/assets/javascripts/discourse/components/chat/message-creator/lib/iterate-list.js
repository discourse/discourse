export function getNext(list, currentIdentifier = null) {
  if (list.length === 0) {
    return null;
  }

  list = list.filterBy("enabled");

  if (currentIdentifier) {
    const currentIndex = list.mapBy("identifier").indexOf(currentIdentifier);

    if (currentIndex < list.length - 1) {
      return list.objectAt(currentIndex + 1);
    } else {
      return list[0];
    }
  } else {
    return list[0];
  }
}

export function getPrevious(list, currentIdentifier = null) {
  if (list.length === 0) {
    return null;
  }

  list = list.filterBy("enabled");

  if (currentIdentifier) {
    const currentIndex = list.mapBy("identifier").indexOf(currentIdentifier);

    if (currentIndex > 0) {
      return list.objectAt(currentIndex - 1);
    } else {
      return list.objectAt(list.length - 1);
    }
  } else {
    return list.objectAt(list.length - 1);
  }
}
