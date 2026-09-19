export function computeStickyNoteRects(stickyNotes) {
  return (stickyNotes || []).map((n) => ({
    clientId: n.clientId,
    x: n.position.x,
    y: n.position.y,
    width: n.size.width,
    height: n.size.height,
  }));
}

function resolveStickyNotes(stickyNotesOrGetter) {
  return typeof stickyNotesOrGetter === "function"
    ? stickyNotesOrGetter()
    : stickyNotesOrGetter;
}

export function buildStickyNoteTranslateHandler(stickyNotesOrGetter, onMove) {
  return (id, dx, dy) => {
    const note = (resolveStickyNotes(stickyNotesOrGetter) || []).find(
      (n) => n.clientId === id
    );
    if (note) {
      onMove?.(id, {
        x: note.position.x + dx,
        y: note.position.y + dy,
      });
    }
  };
}
