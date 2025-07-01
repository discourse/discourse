import AdminConfigAreaCard from "discourse/components/admin-config-area-card";

const COMPONENTS_FOR_CUSTOM_CARDS = [];

export function addCardToAdminThemesGrid(func) {
  COMPONENTS_FOR_CUSTOM_CARDS.push(func(AdminConfigAreaCard));
}

export function resetCardsForAdminThemesGrid() {
  COMPONENTS_FOR_CUSTOM_CARDS.length = 0;
}

export function getCardsForAdminThemesGrid() {
  return COMPONENTS_FOR_CUSTOM_CARDS;
}
