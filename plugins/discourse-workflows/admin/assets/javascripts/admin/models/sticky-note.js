export const STICKY_NOTE_TYPE = "flow:sticky_note";

const DEFAULT_WIDTH = 200;
const DEFAULT_HEIGHT = 150;
const DEFAULT_COLOR = "yellow";

export default class StickyNote {
  static create(args = {}) {
    return new StickyNote(args);
  }

  static serialize(note) {
    return {
      client_id: note.clientId,
      type: STICKY_NOTE_TYPE,
      type_version: "1.0",
      name: "Sticky Note",
      configuration: {
        content: note.text,
        width: note.size.width,
        height: note.size.height,
        color: note.color,
      },
      position: note.position,
    };
  }

  static fromNode(node) {
    const config = node.configuration || {};
    return new StickyNote({
      clientId: node.id?.toString() ?? node.clientId,
      position: node.position ?? { x: 0, y: 0 },
      size: {
        width: config.width ?? DEFAULT_WIDTH,
        height: config.height ?? DEFAULT_HEIGHT,
      },
      color: config.color ?? DEFAULT_COLOR,
      text: config.content ?? "",
    });
  }

  constructor(args = {}) {
    this.clientId = args.clientId ?? args.id ?? crypto.randomUUID();
    this.position = args.position ?? { x: 0, y: 0 };
    this.size = args.size ?? { width: DEFAULT_WIDTH, height: DEFAULT_HEIGHT };
    this.color = args.color ?? DEFAULT_COLOR;
    this.text = args.text ?? "";
  }
}
