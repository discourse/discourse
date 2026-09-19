function classifyValue(value) {
  if (Array.isArray(value)) {
    return "array";
  }

  if (value === null || value === undefined) {
    return value === null ? "null" : "unknown";
  }

  if (typeof value === "number") {
    return "number";
  }

  if (typeof value === "boolean") {
    return "boolean";
  }

  if (typeof value === "object") {
    return "object";
  }

  return "string";
}

function propertySegment(key) {
  return /^[A-Za-z_$][\w$]*$/.test(key)
    ? `.${key}`
    : `[${JSON.stringify(key)}]`;
}

function arraySegment(index) {
  return `[${index}]`;
}

function compactObject(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([, value]) => value !== undefined)
  );
}

function schemaTypeForValue(value) {
  if (typeof value === "number" && Number.isInteger(value)) {
    return "integer";
  }

  return classifyValue(value);
}

function typeList(schema) {
  const types = Array.isArray(schema.type)
    ? schema.type.map(String)
    : schema.type
      ? [String(schema.type)]
      : [];
  if (types.length) {
    return types;
  }

  if (Object.hasOwn(schema, "const")) {
    return [schemaTypeForValue(schema.const)];
  }

  if (schema.properties) {
    return ["object"];
  }

  if (schema.items) {
    return ["array"];
  }

  return [];
}

function asSchemaObject(schema) {
  return schema && typeof schema === "object" && !Array.isArray(schema)
    ? schema
    : {};
}

function effectiveSchema(schema) {
  schema = asSchemaObject(schema);
  if (!Array.isArray(schema.anyOf)) {
    return schema;
  }

  const { anyOf, ...rest } = schema;
  return anyOf
    .map(effectiveSchema)
    .reduce((combined, branch) => displayUnion(combined, branch), rest);
}

function displayUnion(left, right) {
  if (!Object.keys(left).filter((key) => key !== "$schema").length) {
    return right;
  }

  const result = {};
  const types = [...new Set([...typeList(left), ...typeList(right)])];
  if (types.length) {
    result.type = types;
  }

  for (const key of ["const", "format", "description"]) {
    if (Object.hasOwn(left, key) && left[key] === right[key]) {
      result[key] = left[key];
    }
  }

  if (left.properties || right.properties) {
    result.properties = { ...(left.properties || {}) };
    for (const [name, propertySchema] of Object.entries(
      right.properties || {}
    )) {
      result.properties[name] = Object.hasOwn(result.properties, name)
        ? displayUnion(
            effectiveSchema(result.properties[name]),
            effectiveSchema(propertySchema)
          )
        : propertySchema;
    }
  }

  if (left.items || right.items) {
    result.items = displayUnion(
      effectiveSchema(left.items),
      effectiveSchema(right.items)
    );
  }

  return result;
}

function schemaMetadata(schema) {
  const types = typeList(schema);
  const nullable =
    types.includes("null") && types.some((type) => type !== "null");

  const nonNullTypes = [...new Set(types.filter((type) => type !== "null"))];
  if (nonNullTypes.includes("integer") && nonNullTypes.includes("number")) {
    nonNullTypes.splice(nonNullTypes.indexOf("integer"), 1);
  }

  let type;
  if (nonNullTypes.length > 1) {
    type = "unknown";
  } else {
    type = nonNullTypes[0] || (types.includes("null") ? "null" : "unknown");
  }

  return compactObject({
    type,
    value: Object.hasOwn(schema, "const") ? schema.const : undefined,
    format: schema.format,
    nullable: nullable || undefined,
    description: schema.description,
  });
}

function schemaField(schema, key, id) {
  const definition = effectiveSchema(schema);
  const metadata = schemaMetadata(definition);
  const field = { key, id, ...metadata };

  if (metadata.type === "object") {
    field.children = schemaPropertyFields(definition.properties, id);
  } else if (
    metadata.type === "array" &&
    definition.items &&
    typeof definition.items === "object" &&
    !Array.isArray(definition.items)
  ) {
    field.children = [
      schemaField(definition.items, "0", `${id}${arraySegment(0)}`),
    ];
  }

  return field;
}

function schemaPropertyFields(properties, parentId) {
  if (!properties || typeof properties !== "object") {
    return [];
  }

  return Object.entries(properties).map(([key, propertySchema]) =>
    schemaField(propertySchema, key, `${parentId}${propertySegment(key)}`)
  );
}

export function fieldsForSchema(schema = {}, { prefix = "$json" } = {}) {
  return schemaPropertyFields(effectiveSchema(schema).properties, prefix);
}

function representativeValue(values) {
  const presentValue = values.find(
    (value) => value !== undefined && value !== null
  );
  if (presentValue !== undefined) {
    return presentValue;
  }

  return values.includes(null) ? null : undefined;
}

function childValuesForObject(values, childKey) {
  return values.map((value) =>
    value && typeof value === "object" && !Array.isArray(value)
      ? value[childKey]
      : undefined
  );
}

function childValuesForArray(values, index) {
  return values.map((value) =>
    Array.isArray(value) ? value[index] : undefined
  );
}

function fieldFromValues(values, key, path) {
  const value = representativeValue(values);
  const type = classifyValue(value);
  const field = compactObject({
    key,
    id: path,
    type,
    value,
  });

  if (type === "object") {
    const childKeys = new Set();
    for (const candidate of values) {
      if (
        candidate &&
        typeof candidate === "object" &&
        !Array.isArray(candidate)
      ) {
        Object.keys(candidate).forEach((childKey) => childKeys.add(childKey));
      }
    }
    field.children = [...childKeys].map((childKey) =>
      fieldFromValues(
        childValuesForObject(values, childKey),
        childKey,
        `${path}${propertySegment(childKey)}`
      )
    );
  }

  if (type === "array") {
    const childIndexes = new Set();
    for (const candidate of values) {
      if (Array.isArray(candidate)) {
        candidate.forEach((_, index) => childIndexes.add(index));
      }
    }
    field.children = [...childIndexes].map((index) =>
      fieldFromValues(
        childValuesForArray(values, index),
        index.toString(),
        `${path}${arraySegment(index)}`
      )
    );
  }

  return field;
}

export function schemaFieldsForItems(items = [], { prefix = "$json" } = {}) {
  const jsonItems = items
    .map((item) => item?.json)
    .filter((json) => json && typeof json === "object" && !Array.isArray(json));

  const keys = new Set();
  jsonItems.forEach((json) =>
    Object.keys(json).forEach((key) => keys.add(key))
  );

  const jsonFields = [...keys].map((key) =>
    fieldFromValues(
      jsonItems.map((json) => json[key]),
      key,
      `${prefix}${propertySegment(key)}`
    )
  );

  return jsonFields;
}
