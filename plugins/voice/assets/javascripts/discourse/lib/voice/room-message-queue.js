export default class RoomMessageQueue {
  #queues = new Map();

  enqueue(roomId, handler) {
    const previous = this.#queues.get(roomId) || Promise.resolve();
    const next = previous.catch(() => {}).then(handler);

    this.#queues.set(roomId, next);

    const cleanup = () => {
      if (this.#queues.get(roomId) === next) {
        this.#queues.delete(roomId);
      }
    };

    next.then(cleanup, cleanup);

    return next;
  }

  clear(roomId) {
    this.#queues.delete(roomId);
  }

  clearAll() {
    this.#queues.clear();
  }
}
