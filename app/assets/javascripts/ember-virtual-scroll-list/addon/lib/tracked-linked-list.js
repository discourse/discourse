import {
  createStorage,
  getValue,
  setValue,
} from "ember-tracked-storage-polyfill";
import ListNode from "./list-node";

export default class TrackedLinkedList {
  idToValueMap = new Map();

  collection = createStorage(this, () => false);

  constructor() {
    this.head = null;
    this.tail = null;
    return getValue(this.collection);
  }

  insert(value) {
    // we don't want any duplicate
    if (this.idToValueMap.has(value.id)) {
      return;
    }

    const newNode = new ListNode(value);
    if (!this.head || this.head.value.id > value.id) {
      // Insertion at the beginning of the list
      newNode.child = this.head;
      if (this.head) {
        this.head.parent = newNode;
      } else {
        this.tail = newNode; // If list was empty, new node is also the tail
      }
      this.head = newNode;
    } else {
      // Insertion in the middle or at the end of the list
      let current = this.head;
      while (current.child && current.child.value.id < value.id) {
        current = current.child;
      }
      newNode.child = current.child;
      if (current.child) {
        current.child.parent = newNode;
      } else {
        this.tail = newNode; // New node is the new tail
      }
      current.child = newNode;
      newNode.parent = current;
    }

    this.idToValueMap.set(value.id, newNode);

    setValue(this.collection, this);
  }

  find(callback) {
    let foundNode;

    this.traverseDown((node) => {
      if (callback(node)) {
        foundNode = node;
        return false;
      }
      return true;
    });

    return foundNode;
  }

  findReverse(callback) {
    let foundNode;

    this.traverseUp((node) => {
      if (callback(node)) {
        foundNode = node;
        return false;
      }
      return true;
    });

    return foundNode;
  }

  some(callback) {
    let found = false;
    this.traverseDown((node) => {
      if (callback(node)) {
        found = true;
        return false;
      }
      return true;
    });

    return found;
  }

  filter(callback) {
    const nodes = [];
    this.traverseDown((node) => {
      if (callback(node)) {
        nodes.push(node);
      }
      return true;
    });
    return nodes;
  }

  traverseDown(callback) {
    let current = this.head;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.child;
    }
  }

  traverseUp(callback) {
    let current = this.last;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.parent;
    }
  }

  traverseDownFromNode(node, callback) {
    let current = node;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.child;
    }
  }

  traverseUpFromNode(node, callback) {
    let current = node;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.parent;
    }
  }

  get first() {
    return this.head ? this.head : null;
  }

  get last() {
    return this.tail ? this.tail : null;
  }

  get size() {
    return this.idToValueMap.size;
  }

  get length() {
    return this.size;
  }

  has(node) {
    return this.idToValueMap.has(node.value.id);
  }

  get(id) {
    return this.idToValueMap.get(id);
  }

  delete(value) {
    if (!this.head) {
      return; // List is empty
    }

    if (this.head.value.id === value.id) {
      // The node to delete is the head
      if (this.head === this.tail) {
        // The list has only one node
        this.tail = null;
      }
      this.head = this.head.child;
      if (this.head) {
        this.head.parent = null;
      }
    } else {
      // The node to delete is not the head
      let current = this.head;
      while (current.child && current.child.value.id !== value.id) {
        current = current.child;
      }

      if (current.child) {
        if (current.child === this.tail) {
          // The node to delete is the tail
          this.tail = current;
        }
        current.child = current.child.child; // Bypass the node to delete

        if (current.child) {
          current.child.parent = current; // Update parent reference of the new child
        }
      }
    }

    this.idToValueMap.delete(value.id); // Remove from the map
  }

  forRange(lowId, highId) {
    let result = [];
    let current = this.head;
    while (current) {
      if (current.value.id > highId) {
        break; // Stop iterating if current id is greater than highId
      }
      if (current.value.id >= lowId && current.value.id <= highId) {
        result.push(current);
      }
      current = current.child;
    }
    return result;
  }

  isEmpty() {
    return this.size === 0;
  }

  toArray() {
    const result = [];
    this.traverseDown((node) => {
      result.push(node);
      return true;
    });
    return result;
  }

  findXthNodeBefore(targetNode, x) {
    let n = 0;
    let foundNode;

    this.traverseUpFromNode(targetNode.parent, (node) => {
      n++;

      if (n === x) {
        foundNode = node;
        return false;
      }

      return true;
    });

    return foundNode ?? this.first;
  }

  findXthNodeAfter(targetNode, x) {
    let n = 0;
    let foundNode;

    this.traverseDownFromNode(targetNode.child, (node) => {
      n++;

      if (n === x) {
        foundNode = node;
        return false;
      }

      return true;
    });

    return foundNode ?? this.last;
  }
}
