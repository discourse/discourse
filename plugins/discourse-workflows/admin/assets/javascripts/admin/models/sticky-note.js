const DEFAULT_WIDTH = 200;
const DEFAULT_HEIGHT = 150;
const DEFAULT_COLOR = "yellow";

export default class StickyNote {
  static create(args = {}) {
    return new StickyNote(args);
  }

  static serialize(note) {
    return {
      id: note.clientId,
      position: note.position,
      size: note.size,
      color: note.color,
      text: note.text,
    };
  }

  constructor(args = {}) {
    this.clientId = args.clientId ?? args.id ?? crypto.randomUUID();
    this.position = args.position ?? { x: 0, y: 0 };
    this.size = args.size ?? { width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT };
    this.color = args.color ?? DEFAULT_COLOR;
    this.text = args.text ?? "";
  }
}
