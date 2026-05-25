/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  try {
    app.findCollectionByNameOrId("tourist_spots");
    return;
  } catch (_) {}

  const touristSpotsCollection = new Collection({
    name: "tourist_spots",
    type: "base",
    listRule: "",
    viewRule: "",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "code",
        type: "text",
        required: true,
      },
      {
        name: "name",
        type: "text",
        required: true,
      },
      {
        name: "description",
        type: "text",
        required: false,
      },
      {
        name: "category",
        type: "text",
        required: false,
      },
      {
        name: "icon",
        type: "text",
        required: false,
      },
      {
        name: "color",
        type: "text",
        required: false,
      },
      {
        name: "location",
        type: "geoPoint",
        required: true,
      },
      {
        name: "radius_m",
        type: "number",
        required: false,
        min: 10,
        max: 5000,
      },
      {
        name: "image_url",
        type: "text",
        required: false,
      },
      {
        name: "is_active",
        type: "bool",
        required: false,
      },
      {
        name: "sort_order",
        type: "number",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_tourist_spots_code ON tourist_spots (code)",
      "CREATE INDEX idx_tourist_spots_active ON tourist_spots (is_active)",
    ],
  });

  return app.save(touristSpotsCollection);
}, (app) => {
  try {
    const touristSpotsCollection = app.findCollectionByNameOrId("tourist_spots");
    return app.delete(touristSpotsCollection);
  } catch (_) {
    return;
  }
});
