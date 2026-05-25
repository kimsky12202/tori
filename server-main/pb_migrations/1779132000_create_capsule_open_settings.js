/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const capsulesCollection = app.findCollectionByNameOrId("capsules");

  const capsuleOpenSettingsCollection = new Collection({
    name: "capsule_open_settings",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "capsule",
        type: "relation",
        required: true,
        collectionId: capsulesCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "open_option",
        type: "text",
        required: true,
      },
      {
        name: "open_after_days",
        type: "number",
        required: false,
        min: 1,
        max: 3650,
      },
      {
        name: "open_at",
        type: "date",
        required: false,
      },
      {
        name: "notify_enabled",
        type: "bool",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_capsule_open_settings_unique_capsule ON capsule_open_settings (capsule)",
      "CREATE INDEX idx_capsule_open_settings_open_at ON capsule_open_settings (open_at)",
      "CREATE INDEX idx_capsule_open_settings_open_option ON capsule_open_settings (open_option)",
    ],
  });

  return app.save(capsuleOpenSettingsCollection);
}, (app) => {
  try {
    const capsuleOpenSettingsCollection = app.findCollectionByNameOrId("capsule_open_settings");
    return app.delete(capsuleOpenSettingsCollection);
  } catch (_) {
    return;
  }
});
