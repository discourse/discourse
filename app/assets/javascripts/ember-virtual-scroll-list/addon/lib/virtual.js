import { tracked } from "@glimmer/tracking";

const DIRECTION_TYPE = {
  UP: "UP",
  DOWN: "DOWN",
};

const CALC_TYPE = {
  INIT: "INIT",
  DYNAMIC: "DYNAMIC",
};

class Range {
  @tracked start = null;
  @tracked end = null;
  @tracked padDown = null;
  @tracked padUp = null;
}

export default class Virtual {
  sizes = new Map();
  firstRangeTotalSize = 0;
  firstRangeAverageSize = 0;
  calcType = CALC_TYPE.INIT;
  offset = 0;
  direction = "";
  scrolling = false;
  list = null;
  range = new Range();

  constructor(param, callUpdate) {
    this.param = param;
    this.callUpdate = callUpdate;
  }

  getRange() {
    const range = new Range();
    range.start = this.range.start;
    range.end = this.range.end;
    range.padUp = this.range.padUp;
    range.padDown = this.range.padDown;
    return range;
  }

  isDown() {
    return this.direction === DIRECTION_TYPE.DOWN;
  }

  isUp() {
    return this.direction === DIRECTION_TYPE.UP;
  }

  updateParam(key, value) {
    this.param[key] = value;
  }

  // save each size map by id
  saveSize(id, size) {
    this.sizes.set(id, size);

    if (this.calcType === CALC_TYPE.INIT) {
      this.calcType = CALC_TYPE.DYNAMIC;
    } else {
      this.calcType = CALC_TYPE.DYNAMIC;
    }

    if (
      this.calcType !== CALC_TYPE.FIXED &&
      typeof this.firstRangeTotalSize !== "undefined"
    ) {
      if (this.sizes.size < Math.min(this.param.keeps, this.list.size)) {
        this.firstRangeTotalSize = [...this.sizes.values()].reduce(
          (acc, val) => acc + val,
          0
        );
        this.firstRangeAverageSize = Math.round(
          this.firstRangeTotalSize / this.sizes.size
        );
      } else {
        delete this.firstRangeTotalSize;
      }
    }
  }

  handleDataSourcesChange(list) {
    this.list = list;
    const last = this.list.last;

    if (list.size === 0) {
      return;
    }

    this.updateRange(
      this.range.start ??
        this.list.findXthNodeBefore(
          last,
          Math.min(list.size - 1, this.param.keeps - 1)
        ),
      this.range.end ?? last
    );
  }

  handleScroll(offset) {
    this.direction =
      offset < this.offset || offset === 0
        ? DIRECTION_TYPE.DOWN
        : DIRECTION_TYPE.UP;

    if (this.direction === DIRECTION_TYPE.DOWN) {
      offset = Math.max(offset, offset - 100);
    }

    this.offset = offset;

    const targetNode = this.getNodeAtOffset(this.offset);
    this.updateRangeForNode(targetNode);
  }

  getNodeAtOffset(offset) {
    let cumulativeHeight = 0;
    let foundNode;

    this.list.traverseUp((node) => {
      cumulativeHeight += this.getSizeForId(node.value.id);

      if (cumulativeHeight > offset) {
        foundNode = node;
        return false;
      }
      return true;
    });

    return foundNode ?? this.list.first;
  }

  idsForRange(start, end) {
    return this.list.forRange(start, end).map((node) => node.value.id);
  }

  getSizeForIds(ids) {
    let offset = 0;
    ids.forEach((id) => {
      offset += this.getSizeForId(id);
    });
    return offset;
  }

  getIdsBefore(node) {
    return this.idsForRange(this.list.first, node.parent);
  }

  getIdsAfter(node) {
    return this.idsForRange(node.child, this.list.last);
  }

  getSizeForId(id) {
    return this.sizes.get(id) ?? this.getEstimateSize();
  }

  getOffset(id) {
    id = parseInt(id, 10);
    let offset = 0;
    this.list.traverseUp((node) => {
      if (node.value.id === id) {
        return false;
      }
      offset += this.getSizeForId(node.value.id);
      return true;
    });
    return offset;
  }

  updateRangeForNode(targetNode) {
    const up = this.list.findXthNodeBefore(targetNode, this.param.keeps);
    const down = this.list.findXthNodeAfter(targetNode, this.param.keeps);
    this.updateRange(up, down);
  }

  updateRangeFromNode(targetNode) {
    const up = this.list.findXthNodeBefore(targetNode, this.param.keeps);
    this.updateRange(up, targetNode);
  }

  // setting to a new range and rerender
  updateRange(upperNode, lowerNode, force = false) {
    if (
      !force &&
      this.range.start === upperNode &&
      this.range.end === lowerNode
    ) {
      return;
    }

    this.range.start = upperNode;
    this.range.end = lowerNode;
    this.range.padUp = this.getPadUp();
    this.range.padDown = this.getPadDown();

    this.callUpdate(this.getRange());
  }

  getPadUp() {
    return this.getSizeForIds(this.getIdsBefore(this.range.start));
  }

  getPadDown() {
    return this.getSizeForIds(this.getIdsAfter(this.range.end));
  }

  getEstimateSize() {
    return this.firstRangeAverageSize || this.param.estimateSize;
  }
}
