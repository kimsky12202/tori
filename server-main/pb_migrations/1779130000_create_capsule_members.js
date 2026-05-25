/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const usersCollection = app.findCollectionByNameOrId("users");
  const capsulesCollection = app.findCollectionByNameOrId("capsules");

  const capsuleMembersCollection = new Collection({
    name: "capsule_members",
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
        name: "user",
        type: "relation",
        required: true,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "role",
        type: "text",
        required: false,
      },
      {
        name: "status",
        type: "text",
        required: false,
      },
      {
        name: "invited_by",
        type: "relation",
        required: false,
        collectionId: usersCollection.id,
        minSelect: 1,
        maxSelect: 1,
        cascadeDelete: true,
      },
      {
        name: "accepted_at",
        type: "date",
        required: false,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_capsule_members_unique ON capsule_members (capsule, user)",
      "CREATE INDEX idx_capsule_members_user_status ON capsule_members (user, status)",
      "CREATE INDEX idx_capsule_members_capsule ON capsule_members (capsule)",
    ],
  });

  return app.save(capsuleMembersCollection);
}, (app) => {
  try {
    const capsuleMembersCollection = app.findCollectionByNameOrId("capsule_members");
    return app.delete(capsuleMembersCollection);
  } catch (_) {
    return;
  }
});
