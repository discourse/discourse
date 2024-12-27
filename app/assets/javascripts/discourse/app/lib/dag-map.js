import { makeArray } from "discourse-common/lib/helpers";

export default class DAGMap {
  #implicitNodeIndex = 0;
  #implicitNodes = [];
  #nodes = new Map();
  #incomingEdges = new Map();
  #outgoingEdges = new Map();

  add(key, value, { before, after } = {}) {
    this.#addVertex(key, value);

    if (!before && !after) {
      const implicitNode = this.#implicitNodeIndex++;
      this.#implicitNodes.push(implicitNode);

      this.#addEdge(implicitNode, implicitNode + 1);
      this.#addEdge(implicitNode, key);
      this.#addEdge(key, implicitNode + 1);
      return;
    }

    makeArray(before).forEach((b) => this.#addEdge(key, b));
    makeArray(after).forEach((a) => this.#addEdge(a, key));
  }

  get vertices() {
    return this.#nodes;
  }

  get edges() {
    return this.#incomingEdges;
  }

  sort() {
    const indegrees = {}; // object to store the indegrees of each node
    const queue = []; // queue of items to be added to the result

    [
      ...Array.from(this.#incomingEdges.keys()), // enumerate all edge targets
      ...this.#implicitNodes, // enumerate all implicit nodes to ensure the order is preserved
      ...this.#nodes.keys(), // enumerate all existing nodes
    ].forEach((key) => {
      const values = this.#incomingEdges.get(key);
      indegrees[key] = values?.length ?? indegrees[key] ?? 0;

      // if the node is a root node (indegree = 0), add it to the queue
      if (indegrees[key] === 0) {
        queue.push(key);
      }
    });

    const topologicalOrder = [];

    while (queue.length > 0) {
      const node = queue.shift();

      if (this.#nodes.has(node) || this.#implicitNodes.includes(node)) {
        topologicalOrder.push(node);
      }

      const destinationNodes = this.#outgoingEdges.get(node) || [];

      // decrease the indegrees of the destinationNodes as the current node is already in topological order
      for (const destinationNode of destinationNodes) {
        indegrees[destinationNode]--;

        // if the indegree becomes 0, prepend it to the queue
        if (indegrees[destinationNode] === 0) {
          queue.unshift(destinationNode);
        }
      }
    }

    const result = topologicalOrder.filter((node) => this.#nodes.has(node));

    // check for cycles
    if (result.length !== this.#nodes.size) {
      // eslint-disable-next-line no-console
      console.log("Graph contains cycle!: " + topologicalOrder.join(" -> "));
      return [];
    }

    return result;
  }

  resolve() {
    return this.sort().map((key) => [key, this.#nodes.get(key)]);
  }

  #addEdge(from, to) {
    this.#addLink(this.#outgoingEdges, from, to);
    this.#addLink(this.#incomingEdges, to, from);
  }

  #addLink(map, from, to) {
    const links = map.get(from) || [];
    links.push(to);
    map.set(from, links);
  }

  #addVertex(key, value) {
    this.#nodes.set(key, value);
  }
}
