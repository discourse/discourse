export function getNext(list, current = null) {
  if (list.length === 0) {
    return null;
  }

  list = list.filterBy("enabled");

  if (current?.identifier) {
    const currentIndex = list.mapBy("identifier").indexOf(current?.identifier);

    if (currentIndex < list.length - 1) {
      return list.objectAt(currentIndex + 1);
    } else {
      return list[0];
    }
  } else {
    return list[0];
  }
}

export function getPrevious(list, current = null) {
  if (list.length === 0) {
    return null;
  }

  list = list.filterBy("enabled");

  if (current?.identifier) {
    const currentIndex = list.mapBy("identifier").indexOf(current?.identifier);

    if (currentIndex > 0) {
      return list.objectAt(currentIndex - 1);
    } else {
      return list.objectAt(list.length - 1);
    }
  } else {
    return list.objectAt(list.length - 1);
  }
}
