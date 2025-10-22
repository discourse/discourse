class TrieNode {
  constructor(name, parent) {
    this.name = name;
    this.parent = parent;
    this.children = new Map();
    this.leafIndex = null;
  }
}

// Given a set of strings, this class can allow efficient lookups
// based on suffixes.
//
// By default, it will create one Trie node per character. If your data
// has known delimiters (e.g. / in file paths), you can pass a separator
// to the constructor for better performance.
//
// Matching results will be returned in insertion order
export default class SuffixTrie {
  constructor(separator = "") {
    this._trie = new TrieNode();
    this.separator = separator;
    this._nextIndex = 0;
  }

  add(value) {
    const nodeNames = value.split(this.separator);
    let currentNode = this._trie;

    // Iterate over the nodes backwards. The last one should be
    // at the root of the tree
    for (let i = nodeNames.length - 1; i >= 0; i--) {
      let newNode = currentNode.children.get(nodeNames[i]);
      if (!newNode) {
        newNode = new TrieNode(nodeNames[i], currentNode);
        currentNode.children.set(nodeNames[i], newNode);
      }
      currentNode = newNode;
    }

    currentNode.leafIndex = this._nextIndex++;
  }

  withSuffix(suffix, resultCount = null) {
    const nodeNames = suffix.split(this.separator);

    // Traverse the tree to find the root node for this suffix
    let node = this._trie;
    for (let i = nodeNames.length - 1; i >= 0; i--) {
      node = node.children.get(nodeNames[i]);
      if (!node) {
        return [];
      }
    }

    // Find all the leaves which are descendents of that node
    const leaves = [];
    const descendentNodes = [node];
    while (descendentNodes.length > 0) {
      const thisDescendent = descendentNodes.pop();
      if (thisDescendent.leafIndex !== null) {
        leaves.push(thisDescendent);
      }
      descendentNodes.push(...thisDescendent.children.values());
    }

    // Sort them in-place according to insertion order
    leaves.sort((a, b) => (a.leafIndex < b.leafIndex ? -1 : 1));

    // If a subset of results have been requested, truncate
    if (resultCount !== null) {
      leaves.splice(resultCount);
    }

    // Calculate their full names, and return the joined string
    return leaves.map((leafNode) => {
      const parts = [leafNode.name];

      let ancestorNode = leafNode;
      while (typeof ancestorNode.parent?.name === "string") {
        parts.push(ancestorNode.parent.name);
        ancestorNode = ancestorNode.parent;
      }

      return parts.join(this.separator);
    });
  }
}
