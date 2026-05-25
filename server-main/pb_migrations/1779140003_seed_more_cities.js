/// <reference path="../pb_data/types.d.ts" />

const additionalSpotSeeds = [
  // ===== 세종시 =====
  {
    code: "SEJONG_GOVERNMENT_COMPLEX",
    name: "정부세종청사",
    description: "세종특별자치시의 중앙 행정 클러스터",
    category: "landmark",
    icon: "modern",
    color: "#5B7DFA",
    lat: 36.504039,
    lon: 127.262827,
    radius_m: 300,
    sort_order: 200,
  },
  {
    code: "SEJONG_LAKE_PARK",
    name: "세종호수공원",
    description: "세종시의 대표 호수공원",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 36.483736,
    lon: 127.261782,
    radius_m: 300,
    sort_order: 210,
  },
  {
    code: "SEJONG_ARBORETUM",
    name: "국립세종수목원",
    description: "국내 최대 도심형 수목원",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 36.494040,
    lon: 127.253015,
    radius_m: 300,
    sort_order: 220,
  },
  {
    code: "SEJONG_BEAR_TREE_PARK",
    name: "베어트리파크",
    description: "수목과 동물이 어우러진 테마파크",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 36.582752,
    lon: 127.282332,
    radius_m: 300,
    sort_order: 230,
  },
  {
    code: "SEJONG_PRESIDENTIAL_ARCHIVES",
    name: "대통령기록관",
    description: "역대 대통령 기록물 보관소",
    category: "landmark",
    icon: "modern",
    color: "#5B7DFA",
    lat: 36.503455,
    lon: 127.259600,
    radius_m: 200,
    sort_order: 240,
  },

  // ===== 부산 =====
  {
    code: "BUSAN_HAEUNDAE",
    name: "해운대해수욕장",
    description: "부산의 대표 해변",
    category: "beach",
    icon: "beach",
    color: "#2DA9D6",
    lat: 35.158868,
    lon: 129.160500,
    radius_m: 400,
    sort_order: 300,
  },
  {
    code: "BUSAN_GWANGAN_BRIDGE",
    name: "광안대교",
    description: "부산의 야경 명소",
    category: "landmark",
    icon: "bridge",
    color: "#5B7DFA",
    lat: 35.150740,
    lon: 129.123330,
    radius_m: 400,
    sort_order: 310,
  },
  {
    code: "BUSAN_GAMCHEON",
    name: "감천문화마을",
    description: "알록달록 산복도로 마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 35.097506,
    lon: 129.010624,
    radius_m: 300,
    sort_order: 320,
  },

  // ===== 경주 =====
  {
    code: "GYEONGJU_BULGUKSA",
    name: "불국사",
    description: "유네스코 세계유산, 신라의 사찰",
    category: "temple",
    icon: "temple",
    color: "#8E5CF7",
    lat: 35.789991,
    lon: 129.331955,
    radius_m: 250,
    sort_order: 400,
  },
  {
    code: "GYEONGJU_CHEOMSEONGDAE",
    name: "첨성대",
    description: "현존하는 가장 오래된 천문대",
    category: "landmark",
    icon: "tower",
    color: "#1FAA8C",
    lat: 35.834716,
    lon: 129.218890,
    radius_m: 200,
    sort_order: 410,
  },

  // ===== 제주 =====
  {
    code: "JEJU_HALLASAN",
    name: "한라산",
    description: "대한민국 최고봉",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 33.361481,
    lon: 126.529425,
    radius_m: 1000,
    sort_order: 500,
  },
  {
    code: "JEJU_SEONGSAN",
    name: "성산일출봉",
    description: "유네스코 세계유산, 일출 명소",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 33.458056,
    lon: 126.942222,
    radius_m: 400,
    sort_order: 510,
  },
];

migrate((app) => {
  const touristSpotsCollection = app.findCollectionByNameOrId("tourist_spots");

  for (const seed of additionalSpotSeeds) {
    let existing = null;
    try {
      existing = app.findFirstRecordByData("tourist_spots", "code", seed.code);
    } catch (_) {
      existing = null;
    }

    if (existing) {
      continue;
    }

    const record = new Record(touristSpotsCollection, {
      code: seed.code,
      name: seed.name,
      description: seed.description,
      category: seed.category,
      icon: seed.icon,
      color: seed.color,
      location: { lat: seed.lat, lon: seed.lon },
      radius_m: seed.radius_m,
      is_active: true,
      sort_order: seed.sort_order,
    });

    app.save(record);
  }
}, (app) => {
  for (const seed of additionalSpotSeeds) {
    try {
      const record = app.findFirstRecordByData("tourist_spots", "code", seed.code);
      app.delete(record);
    } catch (_) {
      // ignore if record is already deleted
    }
  }
});
