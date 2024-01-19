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

  /**
   * Inserts a new node with the given value into the linked list in a sorted order.
   *
   * This method first checks for the existence of the node with the same ID to avoid duplicates.
   * If a node with the given ID does not exist, it creates a new node and inserts it into
   * the list while maintaining the sorted order based on the ID. The new node is inserted
   * either at the beginning, in the middle, or at the end of the list depending on its value.
   * The method also updates the head and tail of the list as necessary.
   *
   * The `idToValueMap` is used to track the nodes by their IDs for quick access and to prevent
   * duplicate insertions. This method assumes that each value object contains a unique 'id' property.
   *
   * @param {Object} value - The value object to insert into the list. Must contain an 'id' property.
   * @returns {void}
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example' });
   * list.insert({ id: 2, data: 'example' });
   */
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

  /**
   * Deletes a node from the linked list based on the provided value.
   *
   * This method first checks if the node to be deleted is the head of the list.
   * If so, it updates the head to the next node in the list and adjusts the parent reference.
   * If the deleted node is the tail, it also updates the tail reference.
   * If the node to delete is not the head, the method traverses the list to find and remove the node.
   * The removal involves bypassing the node in the list by adjusting the child references of the adjacent nodes.
   * The method also updates the tail reference if the deleted node is the last node.
   *
   * The `idToValueMap` is also updated to remove the mapping of the deleted node.
   *
   * @param {Object} value - The value object of the node to be deleted. Must contain an 'id' property.
   * @returns {void}
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * list.delete({ id: 1 }); // Deletes the node with id 1
   */
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

  /**
   * Searches for the first node in the linked list that satisfies the provided testing function.
   *
   * This method traverses through the linked list, starting from the head, and applies the callback
   * function to each node. The traversal continues until the callback function returns true for a node,
   * indicating that the node satisfies the search criteria. Once such a node is found, the traversal
   * stops, and that node is returned. If no such node is found, the method returns undefined.
   *
   * @param {Function} callback - A function to test each node of the list. The function should return
   *                              `true` for the node that matches the search criteria. This function
   *                              receives the current node as its argument.
   * @returns {ListNode|null} The first node that satisfies the provided testing function, or `null` if no node
   *                          satisfies the testing function.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * const found = list.find(node => node.value.id === 2);
   * console.log(found); // Outputs the node with id 2
   */
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

  /**
   * Searches for the last node in the linked list that satisfies the provided testing function.
   *
   * This method traverses through the linked list in reverse order, starting from the tail, and
   * applies the callback function to each node. The traversal continues until the callback function
   * returns true for a node, indicating that the node satisfies the search criteria. Once such a node
   * is found, the traversal stops, and that node is returned. If no such node is found, the method
   * returns undefined.
   *
   * @param {Function} callback - A function to test each node of the list. The function should return
   *                              `true` for the node that matches the search criteria. This function
   *                              receives the current node as its argument.
   * @returns {ListNode|null} The last node that satisfies the provided testing function, or `null` if no node
   *                          satisfies the testing function.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * list.insert({ id: 3, data: 'example3' });
   * const found = list.findLast(node => node.value.data.startsWith('example'));
   * console.log(found); // Outputs the last node where data starts with 'example'
   */
  findLast(callback) {
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

  /**
   * Determines whether at least one node in the linked list satisfies the provided testing function.
   *
   * This method traverses through the linked list from the head, applying the callback function
   * to each node. The traversal continues until the callback function returns true for a node,
   * indicating that the condition is satisfied. If such a node is found, the method returns true.
   * If the traversal completes without finding any node that satisfies the condition, the method
   * returns false.
   *
   * @param {Function} callback - A testing function to apply to each node. It should return `true`
   *                              for a node that meets the desired condition. The function receives
   *                              the current node as its argument.
   * @returns {boolean} `true` if at least one node satisfies the testing function; otherwise, `false`.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * const hasEvenId = list.some(node => node.value.id % 2 === 0);
   * console.log(hasEvenId); // Outputs true if there's a node with an even id
   */
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

  /**
   * Creates an array of all nodes in the linked list that satisfy the provided testing function.
   *
   * This method traverses the list from the head to the end, applying the callback function
   * to each node. If the callback function returns true for a node, indicating that it satisfies
   * the condition, that node is added to the resulting array. The method returns this array
   * of filtered nodes after completing the traversal.
   *
   * @param {Function} callback - A testing function to apply to each node. It should return `true`
   *                              for nodes that should be included in the new array. The function
   *                              receives the current node as its argument.
   * @returns {ListNode[]} An array containing all nodes that satisfy the provided function.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * const evenIdNodes = list.filter(node => node.value.id % 2 === 0);
   * console.log(evenIdNodes); // Outputs an array of nodes with even ids
   */
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

  /**
   * Traverses the linked list from the head downwards, applying the provided callback function
   * to each node in the list.
   *
   * The traversal begins at the head of the list and proceeds to each subsequent node, following
   * the child links. The provided callback function is called for each node. The traversal can
   * be stopped prematurely if the callback function returns a falsy value (e.g., `false` or `null`).
   *
   * @param {Function} callback - A function to be executed on each node as the list is traversed.
   *                              It receives the current node as its argument. If the callback
   *                              returns a falsy value, the traversal is stopped.
   * @returns {void}
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * list.traverseDown(node => {
   *   console.log(node.value);
   *   return node.value.id !== 2; // Stops traversing if a node with id 2 is found
   * });
   */
  traverseDown(callback) {
    let current = this.head;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.child;
    }
  }

  /**
   * Traverses the linked list from the tail upwards, applying the provided callback function
   * to each node in the list.
   *
   * The traversal begins at the tail of the list and proceeds to each preceding node, following
   * the parent links. The provided callback function is called for each node. The traversal can
   * be stopped prematurely if the callback function returns a falsy value (e.g., `false` or `null`).
   *
   * @param {Function} callback - A function to be executed on each node as the list is traversed
   *                              in reverse order. It receives the current node as its argument.
   *                              If the callback returns a falsy value, the traversal is stopped.
   * @returns {void}
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * list.traverseUp(node => {
   *   console.log(node.value);
   *   return node.value.id !== 1; // Stops traversing if a node with id 1 is found
   * });
   */
  traverseUp(callback) {
    let current = this.last;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.parent;
    }
  }

  /**
   * Traverses the linked list downwards from a specified node, applying the provided callback function
   * to each node in the traversal path.
   *
   * The traversal starts from the given node and continues to each subsequent node, following
   * the child links. The provided callback function is called for each node encountered during
   * the traversal. The process can be terminated prematurely if the callback function returns
   * a falsy value (e.g., `false` or `null`).
   *
   * @param {ListNode} node - The node from which to start the traversal.
   * @param {Function} callback - A function to be executed on each node as the list is traversed
   *                              downwards. It receives the current node as its argument.
   *                              If the callback returns a falsy value, the traversal is stopped.
   * @returns {void}
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * const startNode = list.find(node => node.value.id === 1);
   * list.traverseDownFromNode(startNode, node => {
   *   console.log(node.value);
   *   return node.value.id !== 2; // Stops traversing if a node with id 2 is found
   * });
   */
  traverseDownFromNode(node, callback) {
    let current = node;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.child;
    }
  }

  /**
   * Traverses the linked list upwards from a specified node, applying the provided callback function
   * to each node in the traversal path.
   *
   * The traversal starts from the given node and continues to each preceding node, following
   * the parent links. The provided callback function is called for each node encountered during
   * the traversal. The process can be terminated prematurely if the callback function returns
   * a falsy value (e.g., `false` or `null`).
   *
   * @param {ListNode} node - The node from which to start the traversal.
   * @param {Function} callback - A function to be executed on each node as the list is traversed
   *                              upwards. It receives the current node as its argument.
   *                              If the callback returns a falsy value, the traversal is stopped.
   * @returns {void}
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'example1' });
   * list.insert({ id: 2, data: 'example2' });
   * const startNode = list.find(node => node.value.id === 2);
   * list.traverseUpFromNode(startNode, node => {
   *   console.log(node.value);
   *   return node.value.id !== 1; // Stops traversing if a node with id 1 is found
   * });
   */
  traverseUpFromNode(node, callback) {
    let current = node;
    let continueTraversing = true;
    while (current && continueTraversing) {
      continueTraversing = callback(current);
      current = current.parent;
    }
  }

  /**
   * Retrieves the zero-based index of a specific node in the linked list.
   *
   * This method traverses the linked list from the head, comparing each node
   * to the given node based on their `value.id`. The search continues until it
   * either finds the matching node or reaches the end of the list. If the node
   * is found, its index is returned. Otherwise, -1 is returned to indicate
   * that the node is not in the list.
   *
   * @param {ListNode} node - The node to search for in the list.
   * @returns {number} The index of the given node in the list, or -1 if not found.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1 });
   * list.insert({ id: 2 });
   * const node = new ListNode({ id: 2 });
   * console.log(list.getIndex(node)); // Outputs the index of the node with id 2
   */
  getIndex(node) {
    let current = this.head;
    let index = 0;
    while (current) {
      if (current.value.id === node.value.id) {
        return index;
      }
      current = current.child;
      index++;
    }
    return -1;
  }

  /**
   * Creates an array of nodes from the linked list that fall within the specified range, inclusive.
   *
   * The method starts from the 'start' node and traverses the list until it reaches the 'end' node
   * or a node with an id greater than the 'end' node's id. Each node that falls within the specified
   * range (inclusive of both start and end) is added to the result array.
   *
   * Note: This method assumes that the nodes are sorted in ascending order based on their id, and
   * that both 'start' and 'end' nodes are part of the list. If either 'start' or 'end' is not provided,
   * the method returns an empty array.
   *
   * @param {ListNode} start - The node from which to start the range.
   * @param {ListNode} end - The node at which to end the range.
   * @returns {ListNode[]} An array of nodes from the list that are within the specified range.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'node1' });
   * list.insert({ id: 2, data: 'node2' });
   * list.insert({ id: 3, data: 'node3' });
   * const startNode = list.find(node => node.value.id === 1);
   * const endNode = list.find(node => node.value.id === 3);
   * const rangeNodes = list.forRange(startNode, endNode);
   * console.log(rangeNodes); // Outputs an array of nodes from id 1 to 3
   */
  forRange(start, end) {
    if (!start || !end) {
      return [];
    }

    let result = [start];
    while (start) {
      if (start.value.id > end.value.id) {
        break; // Stop iterating if start id is greater than end.value.id
      }
      if (start.value.id <= end.value.id) {
        result.push(start);
      }
      start = start.child;
    }
    return result;
  }

  /**
   * Finds the node in the linked list that is 'x' positions before a given target node.
   *
   * This method traverses the list upwards from the parent of the target node, counting each node along the way.
   * When the count reaches 'x', the method returns that node. If 'x' exceeds the number of available nodes,
   * the method returns the first node in the list. The traversal uses the 'parent' link of each node,
   * assuming a doubly linked list structure.
   *
   * @param {ListNode} targetNode - The node from which to start counting backwards.
   * @param {number} x - The number of positions to count back from the target node.
   * @returns {ListNode|null} The node that is 'x' positions before the target node, or the first node if 'x' is out of range.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'node1' });
   * list.insert({ id: 2, data: 'node2' });
   * list.insert({ id: 3, data: 'node3' });
   * const targetNode = list.find(node => node.value.id === 3);
   * const nodeBefore = list.findXthNodeBefore(targetNode, 2);
   * console.log(nodeBefore); // Outputs the node with id 1 (2 nodes before node with id 3)
   */
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

  /**
   * Finds the node in the linked list that is 'x' positions after a given target node.
   *
   * This method traverses the list downwards from the child of the target node, counting each node along the way.
   * When the count reaches 'x', the method returns that node. If 'x' exceeds the number of nodes available
   * after the target node, the method returns the last node in the list. The traversal uses the 'child' link of
   * each node, moving forward in the list.
   *
   * @param {ListNode} targetNode - The node from which to start counting forwards.
   * @param {number} x - The number of positions to count forward from the target node.
   * @returns {ListNode|null} The node that is 'x' positions after the target node, or the last node if 'x' is out of range.
   *
   * Example usage:
   * const list = new TrackedLinkedList();
   * list.insert({ id: 1, data: 'node1' });
   * list.insert({ id: 2, data: 'node2' });
   * list.insert({ id: 3, data: 'node3' });
   * const targetNode = list.find(node => node.value.id === 1);
   * const nodeAfter = list.findXthNodeAfter(targetNode, 2);
   * console.log(nodeAfter); // Outputs the node with id 3 (2 nodes after node with id 1)
   */
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
}
