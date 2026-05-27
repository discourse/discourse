export function computeStickyNoteRects(stickyNotes) {
  return (stickyNotes || []).map((n) => ({
    x: n.position.x,
    y: n.position.y,
    width: n.size.width,
    height: n.size.height,
  }));
}

export function buildStickyNoteTranslateHandler(stickyNotes, onMove) {
  return (id, dx, dy) => {
    const note = (stickyNotes || []).find((n) => n.clientId === id);
    if (note) {
      onMove?.(id, {
        x: note.position.x + dx,
        y: note.position.y + dy,
      });
    }
  };
}
