/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  try {
    app.findCollectionByNameOrId("capsules");
    return;
  } catch (_) {}

  const usersCollection = app.findCollectionByNameOrId("users");

  const capsulesCollection = new Collection({
    name: "capsules",
    type: "base",
    listRule: "users = @request.auth.id",
    viewRule: "users = @request.auth.id",
    createRule: "users = @request.auth.id",
    updateRule: "users = @request.auth.id",
    deleteRule: "users = @request.auth.id",
    fields: [
      {
        name: "users",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "location",
        type: "geoPoint",
        required: true,
      },
      {
        name: "memo",
        type: "text",
        required: false,
      },
      {
        name: "emotion",
        type: "text",
        required: false,
      },
      {
        name: "music_title",
        type: "text",
        required: false,
      },
      {
        name: "music_artist",
        type: "text",
        required: false,
      },
      {
        name: "status",
        type: "text",
        required: false,
      },
      {
        name: "photos",
        type: "file",
        required: false,
        maxSize: 5 * 1024 * 1024,
        maxSelect: 10,
        mimeTypes: [
          "image/jpeg",
          "image/png",
          "image/webp",
          "image/heic",
          "image/heif",
        ],
        thumbs: [],
        protected: false,
      },
      {
        name: "videos",
        type: "file",
        required: false,
        maxSize: 50 * 1024 * 1024,
        maxSelect: 10,
        mimeTypes: [
          "video/mp4",
          "video/quicktime",
          "video/webm",
          "video/x-matroska",
        ],
        thumbs: [],
        protected: false,
      },
      {
        name: "music",
        type: "file",
        required: false,
        maxSize: 20 * 1024 * 1024,
        maxSelect: 1,
        mimeTypes: [
          "audio/mpeg",
          "audio/mp4",
          "audio/x-m4a",
          "audio/wav",
          "audio/ogg",
          "audio/webm",
        ],
        thumbs: [],
        protected: false,
      },
      {
        name: "buried_at",
        type: "date",
        required: false,
      },
      {
        name: "created",
        type: "autodate",
        onCreate: true,
        onUpdate: false,
      },
      {
        name: "updated",
        type: "autodate",
        onCreate: true,
        onUpdate: true,
      },
    ],
    indexes: [
      "CREATE INDEX idx_capsules_users ON capsules (users)",
      "CREATE INDEX idx_capsules_status ON capsules (status)",
      "CREATE INDEX idx_capsules_users_created ON capsules (users, created)",
    ],
  });

  return app.save(capsulesCollection);
}, (app) => {
  try {
    const capsulesCollection = app.findCollectionByNameOrId("capsules");
    return app.delete(capsulesCollection);
  } catch (_) {
    return;
  }
});
