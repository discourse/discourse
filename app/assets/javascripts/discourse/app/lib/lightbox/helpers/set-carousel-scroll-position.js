import { SELECTORS } from "../constants";

export async function setCarouselScrollPosition({ behavior = "instant" } = {}) {
  const carouselItem = document.querySelector(SELECTORS.ACTIVE_CAROUSEL_ITEM);

  if (!carouselItem) {
    return;
  }

  const left =
    carouselItem.offsetLeft -
    carouselItem.offsetWidth -
    carouselItem.offsetWidth / 2;

  const top =
    carouselItem.offsetTop -
    carouselItem.offsetHeight -
    carouselItem.offsetHeight / 2;

  carouselItem.parentElement.scrollTo({
    behavior,
    left,
    top,
  });
}
