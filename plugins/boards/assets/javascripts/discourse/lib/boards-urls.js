export function boardsBoardUrl(board) {
  return `/boards/${board.slug}/${board.id}`;
}

export function boardsBoardConfigureUrl(board) {
  return `${boardsBoardUrl(board)}/configure`;
}

export function boardsCardUrl(board, cardId) {
  return `${boardsBoardUrl(board)}/cards/${cardId}`;
}
