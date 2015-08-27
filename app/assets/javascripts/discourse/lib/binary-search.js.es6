// The binarySearch() function is licensed under the UNLICENSE
// https://github.com/Olical/binary-search

// Modified for use in Discourse

export default function binarySearch(list, target, keyProp) {
  var min = 0;
  var max = list.length - 1;
  var guess;
  var keyProperty = keyProp || "id";

  while (min <= max) {
    guess = Math.floor((min + max) / 2);

    if (Em.get(list[guess], keyProperty) === target) {
      return guess;
    }
    else {
      if (Em.get(list[guess], keyProperty) < target) {
        min = guess + 1;
      }
      else {
        max = guess - 1;
      }
    }
  }

  return -Math.floor((min + max) / 2);
}
