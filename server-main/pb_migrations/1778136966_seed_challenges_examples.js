/// <reference path="../pb_data/types.d.ts" />

const challengeSeeds = [
  {
    code: "TRAVEL_START",
    title: "여행 시작",
    description: "여행을 1회 생성해보세요.",
    category: "travel",
    challenge_type: "one_time",
    condition_type: "travel_created",
    condition_value: 1,
    reward_type: "point",
    reward_value: 100,
    icon: "travel_start",
    is_active: true,
    sort_order: 10,
  },
  {
    code: "CAPSULE_BEGINNER",
    title: "첫 캡슐 작성",
    description: "캡슐을 1개 생성해보세요.",
    category: "capsule",
    challenge_type: "one_time",
    condition_type: "capsule_created",
    condition_value: 1,
    reward_type: "badge",
    reward_value: 1,
    icon: "capsule_beginner",
    is_active: true,
    sort_order: 20,
  },
  {
    code: "CAPSULE_COLLECTOR_5",
    title: "캡슐 수집가",
    description: "캡슐을 총 5개 생성해보세요.",
    category: "capsule",
    challenge_type: "one_time",
    condition_type: "capsule_created",
    condition_value: 5,
    reward_type: "point",
    reward_value: 300,
    icon: "capsule_collector",
    is_active: true,
    sort_order: 30,
  },
  {
    code: "PHOTO_ARCHIVIST_10",
    title: "사진 기록가",
    description: "사진을 총 10장 업로드해보세요.",
    category: "photo",
    challenge_type: "one_time",
    condition_type: "photo_uploaded",
    condition_value: 10,
    reward_type: "point",
    reward_value: 200,
    icon: "photo_archivist",
    is_active: true,
    sort_order: 40,
  },
  {
    code: "LOGIN_STREAK_7",
    title: "7일 연속 접속",
    description: "7일 연속으로 로그인해보세요.",
    category: "login",
    challenge_type: "one_time",
    condition_type: "consecutive_login",
    condition_value: 7,
    reward_type: "point",
    reward_value: 500,
    icon: "login_streak",
    is_active: true,
    sort_order: 50,
  },
  {
    code: "CAPSULE_VIEWER_10",
    title: "캡슐 열람자",
    description: "캡슐 상세를 10회 열람해보세요.",
    category: "capsule",
    challenge_type: "one_time",
    condition_type: "capsule_viewed",
    condition_value: 10,
    reward_type: "point",
    reward_value: 150,
    icon: "capsule_viewer",
    is_active: true,
    sort_order: 60,
  },
  {
    code: "PLACE_EXPLORER_3",
    title: "장소 탐험가",
    description: "특정 장소를 3회 방문해보세요.",
    category: "location",
    challenge_type: "one_time",
    condition_type: "place_visited",
    condition_value: 3,
    reward_type: "point",
    reward_value: 250,
    icon: "place_explorer",
    is_active: true,
    sort_order: 70,
  },
];

migrate((app) => {
  const challengesCollection = app.findCollectionByNameOrId("challenges");

  for (const seed of challengeSeeds) {
    let existing = null;
    try {
      existing = app.findFirstRecordByData("challenges", "code", seed.code);
    } catch (_) {
      existing = null;
    }

    if (existing) {
      continue;
    }

    const record = new Record(challengesCollection, seed);
    app.save(record);
  }
}, (app) => {
  for (const seed of challengeSeeds) {
    try {
      const record = app.findFirstRecordByData("challenges", "code", seed.code);
      app.delete(record);
    } catch (_) {
      // ignore if record is already deleted
    }
  }
});
